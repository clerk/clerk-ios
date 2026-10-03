import { createHash, randomBytes, randomUUID } from 'node:crypto';
import { appendFileSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, relative, resolve } from 'node:path';
import { currentProcess, isRunning, sleep, type ProcessRef } from './exec.ts';
import { advanceSlot, readSlot } from './slot.ts';
import {
  VerifyFailure,
  type EvidencePath,
  type Lease,
  type LedgerEntry,
  type Platform,
  type RunId,
  type ScratchPath,
} from './types.ts';

export interface WorkspaceOptions {
  readonly skillDir: string;
  readonly worktree: string;
  readonly home?: string;
}

export interface Workspace {
  readonly root: string;
  readonly skillDir: string;
  readonly worktree: string;
  readonly worktreeId: string;
  readonly home: string;
  readonly ledgerFile: string;
  readonly claimsDir: string;
  newRun(): { readonly run: RunId; readonly dir: EvidencePath; readonly scratch: ScratchPath };
  runDir(run: RunId): EvidencePath;
  runs(): readonly RunId[];
  scratchDir(run: RunId): ScratchPath;
  buildsDir(): ScratchPath;
  leaseFile(platform: Platform): string;
  readLease(platform: Platform): Lease | null;
  writeLease(lease: Lease): void;
  clearLease(platform: Platform): void;
  append(entry: LedgerEntry): void;
  entries(): readonly LedgerEntry[];
  unclosedEntries(): readonly LedgerEntry[];
  withAcquireLock<T>(platform: Platform, fn: () => Promise<T>): Promise<T>;
  withDevice<T>(platform: Platform, waitSeconds: number, fn: () => Promise<T>): Promise<T>;
  removeScratch(path: ScratchPath): void;
}

export const newEntryId = (): string => randomUUID();

export function worktreeIdOf(worktree: string): string {
  return createHash('sha256').update(resolve(worktree)).digest('hex').slice(0, 12);
}

export function newRunId(now: Date = new Date()): RunId {
  const pad = (n: number) => String(n).padStart(2, '0');
  const date = `${now.getFullYear()}${pad(now.getMonth() + 1)}${pad(now.getDate())}`;
  const time = `${pad(now.getHours())}${pad(now.getMinutes())}${pad(now.getSeconds())}`;
  return `r${date}-${time}-${randomBytes(2).toString('hex')}` as RunId;
}

const RUN_ID = /^r\d{8}-\d{6}-[0-9a-f]{4}$/;
export function parseRunId(value: string): RunId {
  if (!RUN_ID.test(value)) throw new VerifyFailure('USAGE', `${value} is not a run id`, 'pass an id like r20261002-141210-7c1e from `verify run`');
  return value as RunId;
}

function isPlatform(value: unknown): value is Platform {
  return value === 'ios' || value === 'android';
}

function parseLease(text: string, file: string): Lease {
  const raw: unknown = JSON.parse(text);
  const bad = () => new VerifyFailure('LEASE_LOST', `${file} is not a lease`, 'verify down, then verify up');
  if (typeof raw !== 'object' || raw === null) throw bad();
  const r = raw as Record<string, unknown>;
  if (!isPlatform(r.platform) || typeof r.acquiredAt !== 'string') throw bad();
  const installedBuild = typeof r.installedBuild === 'string' ? r.installedBuild : null;
  if (r.backend === 'local') {
    if (typeof r.slot !== 'number' || typeof r.deviceName !== 'string' || typeof r.deviceId !== 'string' || typeof r.claim !== 'string') throw bad();
    if (r.deviceName !== `verify-${r.platform}-${r.slot}`) throw bad();
    return { ...(r as object), installedBuild } as Lease;
  }
  if (r.backend === 'eas') {
    if (typeof r.sessionId !== 'string' || typeof r.sessionUrl !== 'string') throw bad();
    return { ...(r as object), installedBuild } as Lease;
  }
  throw bad();
}

function writePrivate(file: string, text: string): void {
  writeFileSync(file, text, { mode: 0o600 });
}

export async function withSlotLock<T>(dir: string, timeoutMs: number, onTimeout: () => VerifyFailure, fn: () => Promise<T>): Promise<T> {
  const deadline = Date.now() + timeoutMs;
  const me = currentProcess();
  let held: number;
  for (;;) {
    const state = readSlot(dir);
    const running = state.value !== null && isRunning(JSON.parse(state.value) as ProcessRef);
    if (!running && advanceSlot(dir, state.gen, JSON.stringify(me))) {
      held = state.gen + 1;
      break;
    }
    if (running) {
      if (Date.now() >= deadline) throw onTimeout();
      await sleep(250);
    }
  }
  try {
    return await fn();
  } finally {
    advanceSlot(dir, held, null);
  }
}

export function openWorkspace(options: WorkspaceOptions): Workspace {
  const root = join(options.skillDir, '.verify');
  const home = options.home ?? join(homedir(), '.verify');
  const worktreeId = worktreeIdOf(options.worktree);
  const ledgerFile = join(home, 'ledgers', `${worktreeId}.jsonl`);
  const claimsDir = join(home, 'claims');
  const dir = (...parts: string[]) => {
    const path = join(root, ...parts);
    mkdirSync(path, { recursive: true });
    return path;
  };
  const readEntries = (): LedgerEntry[] => {
    if (!existsSync(ledgerFile)) return [];
    return readFileSync(ledgerFile, 'utf8')
      .split('\n')
      .filter((line) => line.trim().length > 0)
      .map((line) => JSON.parse(line) as LedgerEntry);
  };

  return {
    root,
    skillDir: options.skillDir,
    worktree: options.worktree,
    worktreeId,
    home,
    ledgerFile,
    claimsDir,
    newRun() {
      const run = newRunId();
      return { run, dir: dir('runs', run) as EvidencePath, scratch: dir('scratch', run) as ScratchPath };
    },
    runDir: (run) => join(root, 'runs', run) as EvidencePath,
    runs: () => (existsSync(join(root, 'runs')) ? readdirSync(join(root, 'runs')).filter((name) => RUN_ID.test(name)).sort() as RunId[] : []),
    scratchDir: (run) => dir('scratch', run) as ScratchPath,
    buildsDir: () => dir('builds') as ScratchPath,
    leaseFile: (platform) => join(root, 'leases', `${platform}.json`),
    readLease(platform) {
      const file = join(root, 'leases', `${platform}.json`);
      return existsSync(file) ? parseLease(readFileSync(file, 'utf8'), file) : null;
    },
    writeLease(lease) {
      writePrivate(join(dir('leases'), `${lease.platform}.json`), `${JSON.stringify(lease, null, 2)}\n`);
    },
    clearLease(platform) {
      rmSync(join(root, 'leases', `${platform}.json`), { force: true });
    },
    append(entry) {
      mkdirSync(join(home, 'ledgers'), { recursive: true });
      const owner = join(home, 'ledgers', `${worktreeId}.owner`);
      if (!existsSync(owner)) writePrivate(owner, `${resolve(options.worktree)}\n`);
      appendFileSync(ledgerFile, `${JSON.stringify(entry)}\n`, { mode: 0o600, flag: 'a' });
    },
    entries: readEntries,
    unclosedEntries() {
      const entries = readEntries();
      const closed = new Set(entries.flatMap((e) => (e.kind === 'done' ? [e.ref] : [])));
      return entries.filter((e) => e.kind !== 'done' && !closed.has(e.id));
    },
    withAcquireLock(platform, fn) {
      return withSlotLock(join(dir('locks'), `acquire-${platform}`), Number.POSITIVE_INFINITY, () => new VerifyFailure('DEVICE_BUSY', 'unreachable', ''), fn);
    },
    withDevice(platform, waitSeconds, fn) {
      return withSlotLock(
        join(dir('locks'), `device-${platform}`),
        waitSeconds * 1000,
        () => new VerifyFailure('DEVICE_BUSY', `another verify process in this worktree is driving the ${platform} device`, 'wait for it to finish, or pass --wait <seconds>'),
        fn,
      );
    },
    removeScratch(path) {
      const rel = relative(root, path);
      if (!(rel.startsWith('scratch') || rel.startsWith('builds')) || rel.includes('..')) {
        throw new VerifyFailure('EVIDENCE_UNSAFE', `${path} is not scratch`, 'only .verify/scratch and .verify/builds are deletable');
      }
      rmSync(path, { recursive: true, force: true });
    },
  };
}
