import { constants, generateKeyPairSync, privateDecrypt, randomBytes } from 'node:crypto';
import { createWriteStream, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { Readable } from 'node:stream';
import { pipeline } from 'node:stream/promises';
import { run, sleep } from '../../core/exec.ts';
import {
  VerifyFailure,
  type AcquireRequest,
  type DeviceBackend,
  type DoctorCheck,
  type EvidencePath,
  type Platform,
  type Recording,
  type RemoteLease,
} from '../../core/types.ts';

/**
 * Prototype remote backend: a simulator or emulator on a GitHub-hosted runner, started by the remote-sim workflow
 * and driven through agent-device over a cloudflared tunnel. The runner is one provider of the remote option;
 * EAS or a Mac mini would implement the same lease shape with their own start, publish, and stop.
 */
export interface GithubRunnerOptions {
  readonly platform: Platform;
  readonly repo: string;
  readonly ref: string;
  readonly workflow: string;
  readonly sessionsDir: string;
  readonly runnerLabel?: string;
  readonly device?: string;
  readonly minutes?: number;
  /** build: the runner compiles and installs the host. none: the driver installs it through the daemon. */
  readonly app?: 'build' | 'none';
  readonly agentDeviceVersion: string;
}

interface PublishedSession {
  readonly session: string;
  readonly platform: Platform;
  readonly tunnel: string;
  readonly deviceId: string;
  readonly device: string;
  readonly agentDeviceVersion: string;
  readonly app: string;
  readonly tokenCiphertext: string;
  readonly publishedAt: string;
}

async function gh(args: readonly string[]): Promise<string> {
  const result = await run('gh', args);
  if (result.code !== 0) throw new VerifyFailure('NOT_READY', `gh ${args[0]} ${args[1] ?? ''} failed: ${result.stderr.trim() || result.stdout.trim()}`, 'run `gh auth status`');
  return result.stdout.trim();
}

export function githubRunnerBackend(options: GithubRunnerOptions): DeviceBackend<RemoteLease> {
  const { platform, repo, ref, workflow } = options;
  const sessionDir = (session: string) => join(options.sessionsDir, session);

  async function runStatus(runId: string): Promise<{ status: string; conclusion: string | null }> {
    return JSON.parse(await gh(['run', 'view', runId, '-R', repo, '--json', 'status,conclusion'])) as { status: string; conclusion: string | null };
  }

  async function waitForArtifact(runId: string, name: string, into: string, timeoutMs: number, progress: (line: string) => void): Promise<void> {
    const deadline = Date.now() + timeoutMs;
    let announced = false;
    for (;;) {
      const list = JSON.parse(await gh(['api', `repos/${repo}/actions/runs/${runId}/artifacts`])) as { artifacts: { name: string; expired: boolean }[] };
      if (list.artifacts.some((a) => a.name === name && !a.expired)) {
        mkdirSync(into, { recursive: true });
        await gh(['run', 'download', runId, '-R', repo, '-n', name, '-D', into]);
        return;
      }
      const state = await runStatus(runId);
      if (state.status === 'completed') {
        throw new VerifyFailure('NOT_READY', `run ${runId} ended (${state.conclusion}) before it published ${name}`, `read https://github.com/${repo}/actions/runs/${runId}`);
      }
      if (Date.now() >= deadline) throw new VerifyFailure('NOT_READY', `run ${runId} did not publish ${name} within ${Math.round(timeoutMs / 60000)} min`, `read https://github.com/${repo}/actions/runs/${runId}`);
      if (!announced) {
        progress(`wait    runner ${runId} is ${state.status}; waiting for ${name}`);
        announced = true;
      }
      await sleep(10_000);
    }
  }

  async function call(lease: RemoteLease, path: string, init: { method?: string } = {}): Promise<Response> {
    const token = readFileSync(lease.tokenFile, 'utf8');
    return fetch(`${lease.baseUrl}${path}`, { ...init, headers: { Authorization: `Bearer ${token}` } });
  }

  async function health(lease: RemoteLease): Promise<boolean> {
    try {
      const sim = await call(lease, '/__sim/health');
      const daemon = await call(lease, '/agent-device/health');
      return sim.status === 200 && daemon.status === 200 && /"ok":\s*true/.test(await daemon.text());
    } catch {
      return false;
    }
  }

  const backend: DeviceBackend<RemoteLease> = {
    kind: 'remote',
    platform,
    supports: () => true,
    requirement: 'gh logged in to a repo that carries the remote-sim workflow',

    async acquire(request: AcquireRequest) {
      const session = `${platform}-${randomBytes(3).toString('hex')}`;
      const dir = sessionDir(session);
      mkdirSync(dir, { recursive: true, mode: 0o700 });
      const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
      const publicPem = Buffer.from(publicKey.export({ type: 'spki', format: 'pem' })).toString('base64');
      const inputs = {
        session,
        driver_public_key: publicPem,
        platform,
        app: options.app ?? 'build',
        runner: options.runnerLabel ?? 'xcode-27',
        device: options.device ?? 'iPhone Air',
        minutes: String(options.minutes ?? 45),
        agent_device_version: options.agentDeviceVersion,
      };
      request.progress(`device  remote ${platform}  dispatching ${workflow} on ${repo}@${ref} (session ${session})`);
      await gh(['workflow', 'run', workflow, '-R', repo, '--ref', ref, ...Object.entries(inputs).flatMap(([k, v]) => ['-f', `${k}=${v}`])]);
      let runId: string | null = null;
      for (let i = 0; i < 30 && runId === null; i += 1) {
        await sleep(4000);
        const runs = JSON.parse(await gh(['run', 'list', '-R', repo, '--workflow', workflow, '--limit', '10', '--json', 'databaseId,displayTitle'])) as { databaseId: number; displayTitle: string }[];
        runId = runs.find((r) => r.displayTitle.includes(session))?.databaseId.toString() ?? null;
      }
      if (runId === null) throw new VerifyFailure('NOT_READY', `the dispatched ${workflow} run for ${session} never appeared`, `check https://github.com/${repo}/actions`);
      request.progress(`device  remote ${platform}  run ${runId} https://github.com/${repo}/actions/runs/${runId}`);
      await waitForArtifact(runId, `session-${session}`, dir, 30 * 60_000, request.progress);
      const published = JSON.parse(readFileSync(join(dir, 'session.json'), 'utf8')) as PublishedSession;
      const token = privateDecrypt({ key: privateKey, padding: constants.RSA_PKCS1_OAEP_PADDING, oaepHash: 'sha256' }, Buffer.from(published.tokenCiphertext, 'base64')).toString('utf8');
      const tokenFile = join(dir, 'token');
      writeFileSync(tokenFile, token, { mode: 0o600 });
      const lease: RemoteLease = {
        backend: 'remote',
        provider: 'github-actions',
        platform,
        session,
        providerRef: runId,
        baseUrl: published.tunnel,
        tokenFile,
        deviceId: published.deviceId,
        deviceName: `${published.device} on runner ${runId}`,
        expiresAt: new Date(Date.now() + (options.minutes ?? 45) * 60_000).toISOString(),
        app: published.app === 'build' ? 'provider-built' : 'driver-installs',
        acquiredAt: new Date().toISOString(),
        installedBuild: null,
      };
      request.progress(`device  remote ${platform}  tunnel up at ${published.tunnel}`);
      for (let i = 0; i < 12 && !(await health(lease)); i += 1) await sleep(5000);
      await waitForArtifact(runId, `ready-${session}`, dir, 60 * 60_000, request.progress);
      return lease;
    },

    async check(lease) {
      const state = await runStatus(lease.providerRef).catch(() => null);
      if (state === null || state.status === 'completed') return 'lost';
      if (!(await health(lease))) return 'lost';
      return Date.parse(lease.expiresAt) - Date.now() < 5 * 60_000 ? 'expiring' : 'held';
    },

    async install(lease, app) {
      if (lease.app === 'provider-built') return;
      const bin = join(options.sessionsDir, '..', '..', 'node_modules', '.bin', 'agent-device');
      const token = readFileSync(lease.tokenFile, 'utf8');
      const env = { ...process.env, AGENT_DEVICE_STATE_DIR: join(sessionDir(lease.session), 'agent-device') };
      const connected = await run(bin, ['connect', 'proxy', '--daemon-base-url', `${lease.baseUrl}/agent-device`, '--daemon-auth-token', token, '--force'], { env });
      if (connected.code !== 0) throw new VerifyFailure('NOT_READY', `agent-device connect proxy failed: ${connected.stderr.trim()}`, '{cli} down, then {cli} up');
      const selector = platform === 'ios' ? ['--platform', 'ios', '--udid', lease.deviceId] : ['--platform', 'android', '--serial', lease.deviceId];
      const installed = await run(bin, ['install', app.path, ...selector], { env });
      if (installed.code !== 0) throw new VerifyFailure('NOT_READY', `remote install failed: ${installed.stderr.trim() || installed.stdout.trim()}`, 'retry {cli} up');
    },

    async release(lease) {
      try {
        await call(lease, '/__sim/stop', { method: 'POST' });
      } catch {
        // The tunnel may already be gone; cancelling the run below still ends the session.
      }
      for (let i = 0; i < 18; i += 1) {
        const state = await runStatus(lease.providerRef).catch(() => null);
        if (state === null || state.status === 'completed') break;
        await sleep(10_000);
      }
      const state = await runStatus(lease.providerRef).catch(() => null);
      if (state !== null && state.status !== 'completed') await gh(['run', 'cancel', lease.providerRef, '-R', repo]).catch(() => undefined);
      rmSync(lease.tokenFile, { force: true });
    },

    async reapable() {
      return [];
    },

    async startRecording(lease, into) {
      const started = await call(lease, '/__sim/record/start', { method: 'POST' });
      if (started.status !== 200) throw new VerifyFailure('NOT_READY', `remote recording did not start: ${await started.text()}`, 'rerun with --no-video');
      const file = join(into, 'video.mp4') as EvidencePath;
      const recording: Recording = {
        process: { pid: 0, startedAt: Date.now() },
        async stop() {
          const stopped = await call(lease, '/__sim/record/stop', { method: 'POST' });
          if (stopped.status !== 200) return file;
          const download = await call(lease, '/__sim/record/file');
          if (download.status === 200 && download.body !== null) await pipeline(Readable.fromWeb(download.body as import('node:stream/web').ReadableStream), createWriteStream(file));
          return file;
        },
      };
      return recording;
    },

    async logs(lease, since, extraPredicate) {
      const params = new URLSearchParams({ since: since.toISOString() });
      if (extraPredicate !== undefined) params.set('predicate', extraPredicate);
      const response = await call(lease, `/__sim/logs?${params}`);
      return response.status === 200 ? response.text() : `remote logs unavailable: ${response.status}`;
    },

    agentDeviceTarget: (lease) => ({ daemon: 'remote', deviceId: lease.deviceId, baseUrl: `${lease.baseUrl}/agent-device`, tokenFile: lease.tokenFile }),
    describe: (lease) => `remote ${lease.deviceName}`,

    async doctorChecks() {
      const auth = await run('gh', ['auth', 'status']);
      const toolchain: DoctorCheck[] = [auth.code === 0 ? { id: 'gh-auth', ok: true, detail: 'gh is logged in' } : { id: 'gh-auth', ok: false, detail: 'gh is not logged in', fix: 'gh auth login' }];
      const listed = await run('gh', ['api', `repos/${repo}/actions/workflows`]);
      const present = listed.code === 0 && listed.stdout.includes(workflow);
      const device: DoctorCheck[] = [
        present
          ? { id: 'remote-workflow', ok: true, detail: `${workflow} is registered on ${repo}` }
          : { id: 'remote-workflow', ok: false, detail: `${workflow} is not registered on ${repo}`, fix: `push ${workflow} to ${ref} once so GitHub registers it` },
      ];
      return { toolchain, device };
    },
  };
  return backend;
}

export const sessionsDirUnder = (workspaceRoot: string): string => {
  const dir = join(workspaceRoot, 'remote-sessions');
  if (!existsSync(dir)) mkdirSync(dir, { recursive: true, mode: 0o700 });
  return dir;
};
