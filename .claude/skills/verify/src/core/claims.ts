import { randomUUID } from 'node:crypto';
import { existsSync, readdirSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { currentProcess, isRunning, type ProcessRef } from './exec.ts';
import { advanceSlot, readSlot } from './slot.ts';
import { worktreeIdOf } from './workspace.ts';
import type { DeviceName, Platform } from './types.ts';

/**
 * Who holds a machine-wide device slot, ~/.verify/claims/<platform>-<slot>/. A claim is written once and never edited:
 * the slot moves only by compare-and-swap, so one worktree can never overwrite another's claim, and of two processes
 * that reclaim the same orphan only one wins.
 */
export interface Claim {
  readonly platform: Platform;
  readonly slot: number;
  readonly gen: number;
  readonly nonce: string;
  readonly deviceName: DeviceName;
  readonly worktree: string;
  readonly worktreeId: string;
  readonly owner: ProcessRef;
  /** Set while a process deletes the slot's device before freeing it. */
  readonly reaping: boolean;
  readonly createdAt: string;
}

export const defaultClaimsDir = (): string => join(homedir(), '.verify', 'claims');

const slotDir = (dir: string, platform: Platform, slot: number) => join(dir, `${platform}-${slot}`);

export function readClaim(dir: string, platform: Platform, slot: number): { readonly gen: number; readonly claim: Claim | null } {
  const state = readSlot(slotDir(dir, platform, slot));
  return { gen: state.gen, claim: state.value === null ? null : { ...(JSON.parse(state.value) as Omit<Claim, 'gen'>), gen: state.gen } };
}

export function readClaims(dir: string, platform: Platform): readonly Claim[] {
  if (!existsSync(dir)) return [];
  const slots = readdirSync(dir).flatMap((name) => {
    const match = new RegExp(`^${platform}-(\\d+)$`).exec(name);
    return match === null ? [] : [Number(match[1])];
  });
  return slots.flatMap((slot) => {
    const { claim } = readClaim(dir, platform, slot);
    return claim === null ? [] : [claim];
  });
}

/** Takes the slot from generation `from`. Null when another process moved it first. */
export function takeSlot(dir: string, platform: Platform, slot: number, from: number, worktree: string, reaping = false): Claim | null {
  const claim: Omit<Claim, 'gen'> = {
    platform,
    slot,
    nonce: randomUUID(),
    deviceName: `verify-${platform}-${slot}`,
    worktree,
    worktreeId: worktreeIdOf(worktree),
    owner: currentProcess(),
    reaping,
    createdAt: new Date().toISOString(),
  };
  return advanceSlot(slotDir(dir, platform, slot), from, JSON.stringify(claim)) ? { ...claim, gen: from + 1 } : null;
}

/** Frees the slot only while `claim` still holds it. */
export function freeSlot(dir: string, claim: Claim): boolean {
  return advanceSlot(slotDir(dir, claim.platform, claim.slot), claim.gen, null);
}

/** Nobody can come back for it: its worktree is gone, or a process died halfway through reaping it. */
export function isOrphaned(claim: Claim): boolean {
  if (claim.reaping) return !isRunning(claim.owner);
  return !existsSync(claim.worktree) && !isRunning(claim.owner);
}
