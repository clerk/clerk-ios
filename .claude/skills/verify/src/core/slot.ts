import { randomUUID } from 'node:crypto';
import { linkSync, mkdirSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

/**
 * A compare-and-swap register on the file system. Each state is a file named by its generation, and a writer moves
 * the slot from generation g to g + 1 by hard-linking a new file at that name, which fails if anyone else got there
 * first. Exactly one writer wins each generation, so two processes that see the same stale holder never both win.
 */
const NAME = /^\d{12}$/;
const FREE = 'free';
/** Old generations go only once no writer can still be about to link the one after them. */
const PRUNE_AFTER_MS = 60_000;

const nameOf = (gen: number) => String(gen).padStart(12, '0');

function generations(dir: string): number[] {
  let names: string[];
  try {
    names = readdirSync(dir);
  } catch {
    return [];
  }
  return names.filter((n) => NAME.test(n)).map(Number).sort((a, b) => a - b);
}

export interface SlotState {
  readonly gen: number;
  /** null when the slot is free. */
  readonly value: string | null;
}

export function readSlot(dir: string): SlotState {
  for (;;) {
    const gens = generations(dir);
    const gen = gens.at(-1);
    if (gen === undefined) return { gen: 0, value: null };
    try {
      const text = readFileSync(join(dir, nameOf(gen)), 'utf8');
      return { gen, value: text === FREE ? null : text };
    } catch (error) {
      if ((error as NodeJS.ErrnoException).code !== 'ENOENT') throw error;
    }
  }
}

/** Moves the slot from `from` to `from + 1`, holding `value` (null frees it). False when another writer moved it first. */
export function advanceSlot(dir: string, from: number, value: string | null): boolean {
  mkdirSync(dir, { recursive: true });
  const next = from + 1;
  const file = join(dir, nameOf(next));
  const staged = join(dir, `.${randomUUID()}`);
  writeFileSync(staged, value ?? FREE, { mode: 0o600 });
  try {
    linkSync(staged, file);
  } catch (error) {
    if ((error as NodeJS.ErrnoException).code === 'EEXIST') return false;
    throw error;
  } finally {
    rmSync(staged, { force: true });
  }
  const gens = generations(dir);
  if (gens.some((g) => g > next)) {
    rmSync(file, { force: true });
    return false;
  }
  const cutoff = Date.now() - PRUNE_AFTER_MS;
  for (const g of gens) {
    if (g >= next - 1) continue;
    try {
      if (statSync(join(dir, nameOf(g))).mtimeMs < cutoff) rmSync(join(dir, nameOf(g)), { force: true });
    } catch {
      continue;
    }
  }
  return true;
}
