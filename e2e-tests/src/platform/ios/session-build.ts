import { spawnSync } from 'node:child_process';
import { appendFileSync, existsSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { BUILD_HOST, SCHEME, WORKSPACE, builtHost } from '../../host-app.ts';
import { BUILD_COMMAND, appKey, inputTree, newestManifest, pathsOutsideInputs, pinInputTimes, pinsHash, readStored, recordInputTimes, resolvedFile, store, storedBundle, toolchain, type AppIdentity, type InputTree, type Toolchain } from './stored-app.ts';

const RESOLVE_LIMIT_MS = 10 * 60_000;
const SIMULATOR_LIMIT_MS = 10 * 60_000;

export interface AppOutcome {
  readonly state: 'stored' | 'built' | 'failed';
  readonly key: string | null;
  readonly storable: boolean;
  readonly why: string;
}

const dirs = (work: string) => ({ derived: join(work, 'derived'), packages: join(work, 'packages'), resolving: join(work, 'resolve-derived') });

function mark(work: string, name: string): void {
  appendFileSync(join(work, 'marks'), `${name} ${Date.now()}\n`);
}

function say(line: string): void {
  process.stdout.write(`${line}\n`);
}

function runShown(command: string, args: readonly string[], timeoutMs?: number): number {
  say(`$ ${command} ${args.join(' ')}`);
  const ran = spawnSync(command, [...args], { stdio: 'inherit', ...(timeoutMs === undefined ? {} : { timeout: timeoutMs }) });
  return ran.status ?? 1;
}

function writeWhole(file: string, text: string): void {
  writeFileSync(`${file}.part`, text);
  renameSync(`${file}.part`, file);
}

function resolvedPins(worktree: string, work: string, head: string): string | null {
  const stamp = join(work, 'resolved-for');
  const at = existsSync(stamp) ? readFileSync(stamp, 'utf8').trim() : '';
  if (at !== head || pinsHash(worktree) === null) {
    mark(work, 'resolve-started');
    rmSync(resolvedFile(worktree), { force: true });
    const { packages, resolving } = dirs(work);
    const code = runShown('xcodebuild', ['-resolvePackageDependencies', '-workspace', WORKSPACE, '-scheme', SCHEME, '-clonedSourcePackagesDirPath', packages, '-derivedDataPath', resolving], RESOLVE_LIMIT_MS);
    mark(work, 'resolved');
    if (code !== 0) return null;
    writeWhole(stamp, `${head}\n`);
  }
  return pinsHash(worktree);
}

function identify(worktree: string, work: string, tools: Toolchain = toolchain(worktree)): { readonly tree: InputTree; readonly identity: AppIdentity | null; readonly why: string } {
  const tree = inputTree(worktree);
  if (tree.changed.length > 0) return { tree, identity: null, why: `the checkout differs from ${tree.head.slice(0, 12)} in ${tree.changed.slice(0, 3).join(', ')}` };
  const pins = resolvedPins(worktree, work, tree.head);
  if (pins === null) return { tree, identity: null, why: 'the package versions could not be resolved and read' };
  return { tree, identity: { inputs: tree.hash, pins, ...tools, command: BUILD_COMMAND }, why: '' };
}

function refusalToStore(worktree: string, work: string, identity: AppIdentity): string | null {
  if (pinsHash(worktree) !== identity.pins) return 'the build resolved other package versions than the ones in the key';
  const manifest = newestManifest(dirs(work).derived);
  if (manifest === null) return 'the build left no manifest to check its inputs against';
  const outside = pathsOutsideInputs(readFileSync(manifest, 'utf8'), worktree);
  return outside.length === 0 ? null : `the build read files that the key does not cover: ${outside.slice(0, 5).join(', ')}`;
}

function decide(work: string, outcome: AppOutcome): void {
  writeWhole(join(work, 'app.json'), `${JSON.stringify(outcome)}\n`);
  say(`app     ${outcome.state}  ${outcome.key ?? 'no key'}  ${outcome.why}`);
}

function putOnSimulator(work: string, udid: string, app: string | null): number {
  mark(work, 'boot-started');
  const booted = runShown('xcrun', ['simctl', 'bootstatus', udid, '-b'], SIMULATOR_LIMIT_MS);
  if (booted !== 0) return booted;
  mark(work, 'booted');
  writeWhole(join(work, 'booted'), '');
  if (app === null) return 0;
  const installed = runShown('xcrun', ['simctl', 'install', udid, app], SIMULATOR_LIMIT_MS);
  mark(work, 'installed');
  return installed;
}

function buildOrInstallStored(work: string): { readonly code: number; readonly app: string | null } {
  const worktree = process.cwd();
  const { tree, identity, why } = identify(worktree, work);
  const key = identity === null ? null : appKey(identity);
  if (key !== null && readStored(work, key) !== null) {
    decide(work, { state: 'stored', key, storable: false, why: 'built before from the same sources, packages and Xcode, so nothing is built' });
    return { code: 0, app: storedBundle(work, key) };
  }
  const { derived, packages } = dirs(work);
  mkdirSync(derived, { recursive: true });
  const times = pinInputTimes(worktree, derived, tree);
  mark(work, 'build-started');
  const code = runShown('xcodebuild', [...BUILD_HOST, derived, '-clonedSourcePackagesDirPath', packages]);
  mark(work, 'built');
  if (code !== 0) {
    decide(work, { state: 'failed', key, storable: false, why: `xcodebuild exited ${code}` });
    return { code, app: null };
  }
  recordInputTimes(derived, times);
  const refusal = identity === null || key === null ? why : refusalToStore(worktree, work, identity);
  if (identity !== null && key !== null && refusal === null) store(work, builtHost(derived), { key, identity, commit: tree.head, builtAt: new Date().toISOString() });
  decide(work, { state: 'built', key, storable: refusal === null, why: refusal === null ? 'stored for the next session with the same sources, packages and Xcode' : `not stored: ${refusal}` });
  return { code: 0, app: builtHost(derived) };
}

function build(work: string, udid: string): number {
  mkdirSync(work, { recursive: true });
  rmSync(join(work, 'app.json'), { force: true });
  let result: ReturnType<typeof buildOrInstallStored>;
  try {
    result = buildOrInstallStored(work);
  } catch (error) {
    decide(work, { state: 'failed', key: null, storable: false, why: (error as Error).message });
    result = { code: 1, app: null };
  }
  if (udid === '') return result.code;
  const onSimulator = putOnSimulator(work, udid, result.app);
  return result.code !== 0 ? result.code : onSimulator;
}

function setOutputs(values: Readonly<Record<string, string>>): void {
  const text = Object.entries(values).map(([name, value]) => `${name}=${value}\n`).join('');
  const file = process.env.GITHUB_OUTPUT ?? '';
  if (file === '') process.stdout.write(text);
  else appendFileSync(file, text);
}

function name(work: string): number {
  const worktree = process.cwd();
  mkdirSync(work, { recursive: true });
  try {
    const tools = toolchain(worktree);
    const { identity, why } = identify(worktree, work, tools);
    if (identity === null) say(`::warning title=verify::no stored app is used or kept: ${why}`);
    setOutputs({ toolchain: `${tools.xcode}-${tools.sdk}-${tools.arch}`, key: identity === null ? '' : appKey(identity), pins: identity?.pins.slice(0, 32) ?? '' });
  } catch (error) {
    say(`::warning title=verify::no stored app is used or kept: ${(error as Error).message}`);
    setOutputs({ toolchain: 'unknown', key: '', pins: '' });
  }
  return 0;
}

function readOutcome(work: string): AppOutcome | null {
  try {
    return JSON.parse(readFileSync(join(work, 'app.json'), 'utf8')) as AppOutcome;
  } catch {
    return null;
  }
}

function outcome(work: string): number {
  const app = readOutcome(work);
  setOutputs({ state: app?.state ?? 'none', store: app?.state === 'built' && app.storable ? (app.key ?? '') : '', built: app?.state === 'built' ? (app.key ?? '') : '' });
  return 0;
}

export function stageLine(marks: string, app: AppOutcome | null): string {
  const at = marks.split('\n').map((line) => line.trim().split(' ')).filter((parts): parts is [string, string] => parts.length === 2 && /^\d+$/.test(parts[1] ?? '')).map(([stage, ms]) => ({ stage, ms: Number(ms) }));
  const first = at[0]?.ms ?? 0;
  const stages = at.slice(1).sort((a, b) => a.ms - b.ms).map(({ stage, ms }) => `${stage} ${Math.round((ms - first) / 1000)}`);
  return `verify-remote stages, in seconds after the job's first step: app ${app?.state ?? 'none'}${app?.key == null ? '' : ` ${app.key}`}; ${stages.join(', ')}`;
}

function stages(work: string): number {
  say(stageLine(existsSync(join(work, 'marks')) ? readFileSync(join(work, 'marks'), 'utf8') : '', readOutcome(work)));
  return 0;
}

if (import.meta.main) {
  const [command, work = '', udid = ''] = process.argv.slice(2);
  const commands: Readonly<Record<string, () => number>> = { name: () => name(work), build: () => build(work, udid), outcome: () => outcome(work), stages: () => stages(work) };
  const chosen = work === '' ? undefined : commands[command ?? ''];
  if (chosen === undefined) {
    console.error('usage: session-build.ts name|build|outcome|stages <work> [udid]');
    process.exit(2);
  }
  process.exitCode = chosen();
}
