import { createHash } from 'node:crypto';
import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import type { ClerkBackend } from './clerk.ts';
import { run } from './exec.ts';
import { finishOrphanLedgers } from './ledgers.ts';
import { newEntryId, type Workspace } from './workspace.ts';
import {
  VerifyFailure,
  type AcquireLock,
  type BackendKind,
  type BuildKey,
  type BuildView,
  type BuiltApp,
  type DeviceBackend,
  type HostAdapter,
  type Lease,
  type LeaseView,
  type ProcessRef,
  type Platform,
  type ScratchPath,
} from './types.ts';

export interface LeaseOutcome {
  readonly lease: Lease;
  readonly backend: DeviceBackend;
  readonly app: BuiltApp;
  readonly view: LeaseView;
  readonly build: BuildView;
}

export function backendFor(host: HostAdapter, platform: Platform, kind: BackendKind): DeviceBackend {
  const backend = host.backends.find((b) => b.platform === platform && b.kind === kind);
  if (backend === undefined) {
    const others = host.backends.filter((b) => b.platform === platform);
    const fix = others.length === 0 ? `${host.repo} has no ${platform} backend` : `use ${others.map((b) => `--backend ${b.kind} (needs ${b.requirement})`).join(' or ')}`;
    throw new VerifyFailure('UNSUPPORTED', `${host.repo} has no ${kind} backend for ${platform}`, fix);
  }
  return backend;
}

export interface BackendChoice {
  readonly backend: DeviceBackend;
  /** Why this backend, for the `backend` line `doctor`, `up`, and `run` print. */
  readonly why: string;
}

export function selectBackend(host: HostAdapter, platform: Platform, requested: BackendKind | undefined, held: Lease | null, os: NodeJS.Platform = process.platform): BackendChoice {
  if (requested !== undefined) {
    const backend = backendFor(host, platform, requested);
    const forced = backend.availability(os);
    if (!forced.usable) throw new VerifyFailure('UNSUPPORTED', `--backend ${requested} cannot run here: ${forced.why}`, `drop --backend so the CLI picks one, or run on ${backend.requirement}`);
    return { backend, why: `forced by --backend ${requested}` };
  }
  if (held !== null) return { backend: backendFor(host, platform, held.backend), why: `this worktree already holds a ${held.backend} lease` };
  const candidates = host.backends.filter((b) => b.platform === platform).map((backend) => ({ backend, ...backend.availability(os) }));
  const chosen = candidates.find((c) => c.usable);
  if (chosen === undefined) {
    throw new VerifyFailure('UNSUPPORTED', `no ${platform} backend runs on ${os}`, candidates.length === 0 ? `${host.repo} has no ${platform} backend` : `run on ${candidates.map((c) => c.backend.requirement).join(' or ')}`);
  }
  const passed = candidates.slice(0, candidates.indexOf(chosen)).map((c) => `${c.backend.kind} is out: ${c.why}`);
  return { backend: chosen.backend, why: [...passed, chosen.why].join('; ') };
}

export const describeChoice = (choice: BackendChoice): string => `${choice.backend.kind}  ${choice.why}`;

export function leaseView(backend: DeviceBackend, lease: Lease, renewed: boolean): LeaseView {
  return {
    platform: lease.platform,
    backend: lease.backend,
    device: backend.describe(lease),
    installedBuild: lease.installedBuild,
    expiresAt: lease.backend === 'remote' ? lease.expiresAt : null,
    renewed,
  };
}

export function leaseLine(view: LeaseView): string {
  return `device  ${view.device}  ${view.backend}  ${view.renewed ? 'renewed' : 'leased by this worktree'}  installed ${view.installedBuild ?? 'nothing'}`;
}

const BUILD_DENYLIST = [/\.md$/i, /(^|\/)\.claude\//, /(^|\/)docs\//, /(^|\/)\.verify\//];

export async function computeBuildKey(host: HostAdapter, platform: Platform, worktree: string): Promise<BuildKey> {
  const listed = await run('git', ['ls-files', '-z', '--cached', '--others', '--exclude-standard', '--', ...host.buildInputs(platform)], { cwd: worktree });
  if (listed.code !== 0) throw new VerifyFailure('NOT_READY', `git ls-files failed: ${listed.stderr.trim()}`, 'run verify from inside a git worktree');
  const files = [...new Set(listed.stdout.split('\0').filter((f) => f.length > 0 && !BUILD_DENYLIST.some((re) => re.test(f))))].sort();
  const hash = createHash('sha256');
  for (const file of files) {
    const path = join(worktree, file);
    hash.update(file).update('\0');
    hash.update(existsSync(path) ? readFileSync(path) : 'deleted').update('\0');
  }
  return `${platform}-${hash.digest('hex').slice(0, 12)}` as BuildKey;
}

function buildDir(workspace: Workspace, key: BuildKey): ScratchPath {
  return join(workspace.buildsDir(), key) as ScratchPath;
}

export function readBuiltApp(workspace: Workspace, key: BuildKey): BuiltApp | null {
  const file = join(buildDir(workspace, key), 'build.json');
  if (!existsSync(file)) return null;
  const app = JSON.parse(readFileSync(file, 'utf8')) as BuiltApp;
  return existsSync(app.path) ? app : null;
}

async function ensureBuild(host: HostAdapter, platform: Platform, workspace: Workspace, backend: DeviceBackend, held: Lease | null, progress: (line: string) => void): Promise<{ app: BuiltApp; view: BuildView }> {
  const key = await computeBuildKey(host, platform, workspace.worktree);
  if (backend.sourceCommit !== undefined) {
    // A session that already holds this build needs no pushed HEAD: a commit that only touches specs or docs can stay local.
    const onSession = held !== null && held.backend === 'remote' && held.installedBuild === key ? held.builtSha : null;
    const sourceSha = onSession ?? (await backend.sourceCommit({ worktree: workspace.worktree, inputs: host.buildInputs(platform) }));
    const app: BuiltApp = { platform, key, appId: host.appId(platform), path: '' as ScratchPath, source: 'github-actions', sourceSha };
    return { app, view: { platform, key, source: app.source, reused: onSession !== null, seconds: 0 } };
  }
  const existing = readBuiltApp(workspace, key);
  if (existing !== null) return { app: existing, view: { platform, key, source: existing.source, reused: true, seconds: 0 } };
  const source = host.buildSources(platform, process.platform)[0];
  if (source !== 'local') {
    throw new VerifyFailure('UNSUPPORTED', `${host.repo} cannot build ${platform} on ${process.platform} yet (build sources here: ${host.buildSources(platform, process.platform).join(', ') || 'none'})`, `run {cli} up on a machine where ${host.repo} builds ${platform} locally`);
  }
  const started = Date.now();
  progress(`build   ${key}  ${source}  building...`);
  const app = await host.build(platform, source, key, buildDir(workspace, key), progress);
  writeFileSync(join(buildDir(workspace, key), 'build.json'), `${JSON.stringify(app, null, 2)}\n`);
  return { app, view: { platform, key, source, reused: false, seconds: Math.round((Date.now() - started) / 1000) } };
}

function closePending(workspace: Workspace, platform: Platform): void {
  for (const entry of workspace.unclosedEntries()) {
    if ((entry.kind === 'lease-intent' || entry.kind === 'lease-held') && entry.platform === platform) {
      workspace.append({ id: newEntryId(), kind: 'done', ref: entry.id });
    }
  }
}

export async function releaseLease(workspace: Workspace, backend: DeviceBackend, lease: Lease): Promise<void> {
  await backend.release(lease);
  workspace.clearLease(lease.platform);
  closePending(workspace, lease.platform);
}

export async function ensureLease(
  lock: AcquireLock,
  requested: BackendKind | undefined,
  workspace: Workspace,
  host: HostAdapter,
  options: { readonly waitSeconds: number; readonly runner?: string; readonly progress: (line: string) => void; readonly clerk: () => ClerkBackend; readonly retryWith: string },
): Promise<LeaseOutcome> {
  const { platform } = lock;
  const held = workspace.readLease(platform);
  if (held !== null && requested !== undefined && held.backend !== requested) {
    throw new VerifyFailure('NOT_READY', `this worktree holds a ${held.backend} ${platform} lease, not ${requested}`, '{cli} down');
  }
  if (held !== null && held.backend === 'remote' && options.runner !== undefined && held.runner !== options.runner) {
    throw new VerifyFailure('NOT_READY', `this worktree holds a session on ${held.runner}, not ${options.runner}`, '{cli} down, then rerun with --runner');
  }
  const choice = selectBackend(host, platform, requested, held);
  const { backend } = choice;
  options.progress(`backend ${describeChoice(choice)}`);
  for (const stale of await backend.reapable()) {
    options.progress(`reap    ${backend.describe(stale)}  (owner process and worktree are gone)`);
    await backend.release(stale);
  }
  await finishOrphanLedgers(workspace.home, resolve(workspace.worktree), options.clerk, options.progress);

  const { app, view: build } = await ensureBuild(host, platform, workspace, backend, held, options.progress);
  const builtBy = app.sourceSha === null ? (build.reused ? 'reused' : `built in ${build.seconds}s`) : `commit ${app.sourceSha.slice(0, 12)}  ${build.reused ? 'already on the session' : 'the session builds it'}`;
  options.progress(`build   ${build.key}  ${build.source}  ${builtBy}`);

  let lease: Lease | null = held;
  let renewed = false;
  const state = lease === null ? 'held' : await backend.check(lease);
  if (lease !== null && state !== 'held') {
    options.progress(`${(state === 'expiring' ? 'ending' : 'lost').padEnd(7)} ${backend.describe(lease)}  renewing`);
    await releaseLease(workspace, backend, lease);
    lease = null;
    renewed = true;
  }
  if (lease === null) {
    for (const orphan of await backend.reapable(workspace.worktree)) {
      options.progress(`reap    ${backend.describe(orphan)}  (claimed by this worktree with no lease file)`);
      await backend.release(orphan);
    }
    const intent = { id: newEntryId(), kind: 'lease-intent' as const, platform, backend: backend.kind, worktree: workspace.worktree };
    workspace.append(intent);
    const acquired = await backend.acquire({ platform, worktree: workspace.worktree, waitSeconds: options.waitSeconds, app, ...(options.runner === undefined ? {} : { runner: options.runner }), retryWith: options.retryWith, progress: options.progress });
    workspace.writeLease(acquired);
    workspace.append({
      id: newEntryId(),
      kind: 'lease-held',
      platform,
      backend: backend.kind,
      sessionId: acquired.backend === 'remote' ? acquired.session : null,
      deviceId: acquired.deviceId,
    });
    workspace.append({ id: newEntryId(), kind: 'done', ref: intent.id });
    lease = acquired;
  }

  if (lease.installedBuild !== app.key) {
    const target = lease;
    options.progress(`install ${app.key}  on ${backend.describe(target)}`);
    const wait = {
      seconds: options.waitSeconds,
      busyFix: `let the run in this worktree finish, or rerun with a wait: ${options.retryWith}`,
      onWait: (owner: ProcessRef) =>
        options.progress(`wait    another {cli} run in this worktree (pid ${owner.pid}) is driving the device; waiting up to ${options.waitSeconds}s to install`),
    };
    lease = { ...(await workspace.withDevice(platform, wait, () => backend.install(target, app, options.progress))), installedBuild: app.key };
    workspace.writeLease(lease);
  }
  return { lease, backend, app, build, view: leaseView(backend, lease, renewed) };
}
