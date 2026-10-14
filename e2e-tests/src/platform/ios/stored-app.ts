import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';
import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, renameSync, rmSync, statSync, utimesSync, writeFileSync } from 'node:fs';
import { basename, join } from 'node:path';
import { BUILD_HOST, BUILD_INPUTS, WORKSPACE } from '../../host-app.ts';

export interface AppIdentity {
  readonly inputs: string;
  readonly pins: string;
  readonly xcode: string;
  readonly sdk: string;
  readonly arch: string;
  readonly command: string;
}

export interface TreeEntry {
  readonly path: string;
  readonly oid: string;
}

export interface InputTree {
  readonly head: string;
  readonly hash: string;
  readonly entries: readonly TreeEntry[];
  readonly changed: readonly string[];
}

export interface Toolchain {
  readonly xcode: string;
  readonly sdk: string;
  readonly arch: string;
}

export interface StoredApp {
  readonly key: string;
  readonly identity: AppIdentity;
  readonly commit: string;
  readonly builtAt: string;
}

const sha256 = (text: string): string => createHash('sha256').update(text).digest('hex');

export const BUILD_COMMAND = BUILD_HOST.join(' ');

export function appKey(identity: AppIdentity): string {
  return sha256(JSON.stringify([identity.inputs, identity.pins, identity.xcode, identity.sdk, identity.arch, identity.command])).slice(0, 32);
}

function output(command: string, args: readonly string[], cwd: string): string {
  const ran = spawnSync(command, [...args], { cwd, encoding: 'utf8', timeout: 60_000, maxBuffer: 64 * 1024 * 1024 });
  if (ran.status !== 0) throw new Error(`${command} ${args.join(' ')} exited ${ran.status ?? ran.signal}: ${(ran.stderr ?? '').trim() || (ran.error?.message ?? 'no output')}`);
  return ran.stdout;
}

const BUILT_WHOLE = ['Sources', 'Examples/E2EHost'] as const;

export function inputTree(worktree: string): InputTree {
  const listed = output('git', ['ls-tree', '-r', '-t', '-z', 'HEAD', '--', ...BUILD_INPUTS], worktree).split('\0').filter((line) => line !== '');
  const entries = listed.map((line) => {
    const [meta = '', path = ''] = line.split('\t');
    return { path, oid: meta.split(' ')[2] ?? '' };
  });
  const files = listed.filter((line) => line.split(' ')[1] !== 'tree');
  const changed = output('git', ['status', '--porcelain', '-z', '--', ...BUILD_INPUTS], worktree).split('\0').filter((line) => line !== '').map((line) => line.slice(3));
  // SwiftPM targets and Xcode's synchronized folders compile every file in them, ignored by git or not.
  const ignored = output('git', ['status', '--porcelain', '--ignored', '-z', '--', ...BUILT_WHOLE], worktree).split('\0').filter((line) => line.startsWith('!! ')).map((line) => line.slice(3)).filter((path) => basename(path) !== '.DS_Store');
  return { head: output('git', ['rev-parse', 'HEAD'], worktree).trim(), hash: sha256(files.join('\0')), entries, changed: [...changed, ...ignored] };
}

export function toolchain(cwd: string): Toolchain {
  const xcode = /^Build version\s+(\S+)$/m.exec(output('xcodebuild', ['-version'], cwd))?.[1];
  if (xcode === undefined) throw new Error('xcodebuild -version names no build version');
  return { xcode, sdk: output('xcrun', ['--sdk', 'iphonesimulator', '--show-sdk-build-version'], cwd).trim(), arch: process.arch };
}

export const resolvedFile = (worktree: string): string => join(worktree, WORKSPACE, 'xcshareddata', 'swiftpm', 'Package.resolved');

export function pinsHash(worktree: string): string | null {
  let pins: unknown;
  try {
    pins = (JSON.parse(readFileSync(resolvedFile(worktree), 'utf8')) as { readonly pins?: unknown }).pins;
  } catch {
    return null;
  }
  if (!Array.isArray(pins)) return null;
  const lines = pins.map((pin: { readonly identity?: unknown; readonly location?: unknown; readonly state?: { readonly revision?: unknown; readonly version?: unknown; readonly branch?: unknown } }) =>
    [pin.identity, pin.location, pin.state?.revision, pin.state?.version ?? pin.state?.branch ?? ''].map(String).join(' '),
  );
  return sha256(lines.sort().join('\n'));
}

const escaped = (text: string): string => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

export function pathsOutsideInputs(manifest: string, worktree: string): readonly string[] {
  const root = worktree.replace(/\/+$/, '');
  const named = new Set<string>();
  for (const found of manifest.matchAll(new RegExp(`"${escaped(root)}(/[^"]*)?"`, 'g'))) named.add((found[1] ?? '').replace(/^\/+|\/+$/g, ''));
  const under = (path: string, parent: string): boolean => path === parent || path.startsWith(`${parent}/`);
  return [...named].filter((path) => !BUILD_INPUTS.some((input) => under(path, input) || under(input, path) || path === '')).sort();
}

export function newestManifest(derived: string): string | null {
  const dir = join(derived, 'Build', 'Intermediates.noindex', 'XCBuildData');
  if (!existsSync(dir)) return null;
  const found = readdirSync(dir)
    .map((name) => join(dir, name, 'manifest.json'))
    .filter((file) => existsSync(file))
    .map((file) => ({ file, at: statSync(file).mtimeMs }))
    .sort((a, b) => b.at - a.at);
  return found[0]?.file ?? null;
}

const storedDir = (work: string, key: string): string => join(work, 'apps', key);

export const storedBundle = (work: string, key: string): string => join(storedDir(work, key), 'E2EHost.app');

export function readStored(work: string, key: string): StoredApp | null {
  try {
    const stored = JSON.parse(readFileSync(join(storedDir(work, key), 'stored.json'), 'utf8')) as StoredApp;
    return stored.key === key && appKey(stored.identity) === key && existsSync(join(storedBundle(work, key), 'Info.plist')) ? stored : null;
  } catch {
    return null;
  }
}

export function store(work: string, app: string, stored: StoredApp): void {
  const dir = storedDir(work, stored.key);
  const staging = `${dir}.staging`;
  rmSync(staging, { recursive: true, force: true });
  rmSync(dir, { recursive: true, force: true });
  mkdirSync(staging, { recursive: true });
  cpSync(app, join(staging, 'E2EHost.app'), { recursive: true, verbatimSymlinks: true });
  writeFileSync(join(staging, 'stored.json'), `${JSON.stringify(stored, null, 2)}\n`);
  renameSync(staging, dir);
}

type InputTimes = Readonly<Record<string, readonly [oid: string, seconds: number]>>;

const timesFile = (derived: string): string => join(derived, 'verify-input-times.json');

export function pinInputTimes(worktree: string, derived: string, tree: InputTree, now: number = Math.floor(Date.now() / 1000)): InputTimes {
  let recorded: InputTimes = {};
  try {
    recorded = JSON.parse(readFileSync(timesFile(derived), 'utf8')) as InputTimes;
  } catch {
    recorded = {};
  }
  const pinned: Record<string, readonly [string, number]> = {};
  for (const { path, oid } of tree.entries) {
    const was = recorded[path];
    const seconds = was !== undefined && was[0] === oid ? was[1] : now;
    utimesSync(join(worktree, path), seconds, seconds);
    pinned[path] = [oid, seconds];
  }
  return pinned;
}

export function recordInputTimes(derived: string, times: InputTimes): void {
  writeFileSync(timesFile(derived), JSON.stringify(times));
}
