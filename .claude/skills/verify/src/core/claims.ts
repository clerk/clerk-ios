import { closeSync, existsSync, mkdirSync, openSync, readFileSync, readdirSync, rmSync, writeFileSync, writeSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { isAlive } from './exec.ts';
import { worktreeIdOf } from './workspace.ts';
import type { DeviceName, Platform } from './types.ts';

export interface Claim {
  readonly platform: Platform;
  readonly slot: number;
  readonly deviceName: DeviceName;
  readonly deviceId: string | null;
  readonly worktree: string;
  readonly worktreeId: string;
  readonly pid: number;
  readonly createdAt: string;
}

export const defaultClaimsDir = (): string => join(homedir(), '.verify', 'claims');

const claimFile = (dir: string, platform: Platform, slot: number) => join(dir, `${platform}-${slot}.json`);

export function readClaims(dir: string, platform: Platform): readonly Claim[] {
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter((name) => name.startsWith(`${platform}-`) && name.endsWith('.json'))
    .flatMap((name) => {
      try {
        return [JSON.parse(readFileSync(join(dir, name), 'utf8')) as Claim];
      } catch {
        return [];
      }
    });
}

export function readClaim(dir: string, platform: Platform, slot: number): Claim | null {
  const file = claimFile(dir, platform, slot);
  return existsSync(file) ? (JSON.parse(readFileSync(file, 'utf8')) as Claim) : null;
}

export function createClaim(dir: string, platform: Platform, slot: number, worktree: string): Claim | null {
  mkdirSync(dir, { recursive: true });
  const claim: Claim = {
    platform,
    slot,
    deviceName: `verify-${platform}-${slot}`,
    deviceId: null,
    worktree,
    worktreeId: worktreeIdOf(worktree),
    pid: process.pid,
    createdAt: new Date().toISOString(),
  };
  try {
    const fd = openSync(claimFile(dir, platform, slot), 'wx', 0o600);
    writeSync(fd, `${JSON.stringify(claim, null, 2)}\n`);
    closeSync(fd);
    return claim;
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'EEXIST') return null;
    throw error;
  }
}

export function updateClaim(dir: string, claim: Claim): void {
  writeFileSync(claimFile(dir, claim.platform, claim.slot), `${JSON.stringify(claim, null, 2)}\n`, { mode: 0o600 });
}

export function removeClaim(dir: string, platform: Platform, slot: number): void {
  rmSync(claimFile(dir, platform, slot), { force: true });
}

export function isReapable(claim: Claim): boolean {
  return !isAlive(claim.pid) && !existsSync(claim.worktree);
}
