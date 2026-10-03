import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';
import { parseTestEmail, type ClerkBackend } from './clerk.ts';
import { isAlive, type Runner } from './exec.ts';
import { newEntryId, openWorkspace, type Workspace } from './workspace.ts';
import type { InstanceName, LedgerEntry, TestEmail } from './types.ts';

export interface PendingIdentity {
  readonly instance: InstanceName;
  readonly email: TestEmail;
  readonly entries: readonly string[];
}

export function pendingIdentities(entries: readonly LedgerEntry[]): readonly PendingIdentity[] {
  const byEmail = new Map<string, { instance: InstanceName; email: TestEmail; entries: string[] }>();
  for (const entry of entries) {
    if (entry.kind !== 'identity' && entry.kind !== 'user') continue;
    const email = parseTestEmail(entry.email);
    const group = byEmail.get(email) ?? { instance: entry.instance, email, entries: [] };
    group.entries.push(entry.id);
    byEmail.set(email, group);
  }
  return [...byEmail.values()];
}

export async function stopRecorders(workspace: Workspace, runner: Runner): Promise<readonly string[]> {
  const stopped: string[] = [];
  for (const entry of workspace.unclosedEntries()) {
    if (entry.kind !== 'process') continue;
    if (isAlive(entry.pid) && (await runner('ps', ['-o', 'command=', '-p', String(entry.pid)])).stdout.includes('recordVideo')) {
      try {
        process.kill(entry.pid, 'SIGINT');
      } catch (error) {
        if ((error as NodeJS.ErrnoException).code !== 'ESRCH') throw error;
      }
    }
    stopped.push(`${entry.what} ${entry.pid}`);
    workspace.append({ id: newEntryId(), kind: 'done', ref: entry.id });
  }
  return stopped;
}

export async function deleteIdentities(workspace: Workspace, clerk: ClerkBackend): Promise<{ readonly users: number; readonly organizations: number }> {
  let users = 0;
  let organizations = 0;
  for (const identity of pendingIdentities(workspace.unclosedEntries())) {
    const deleted = await clerk.deleteByEmail(identity.instance, identity.email);
    users += deleted.users;
    organizations += deleted.organizations;
    for (const ref of identity.entries) workspace.append({ id: newEntryId(), kind: 'done', ref });
  }
  return { users, organizations };
}

export async function finishOrphanLedgers(
  home: string,
  self: string,
  clerk: () => ClerkBackend,
  runner: Runner,
  progress: (line: string) => void,
): Promise<void> {
  const dir = join(home, 'ledgers');
  if (!existsSync(dir)) return;
  for (const name of readdirSync(dir).filter((n) => n.endsWith('.owner'))) {
    const worktree = readFileSync(join(dir, name), 'utf8').trim();
    if (worktree === self || existsSync(worktree)) continue;
    const ledger = openWorkspace({ skillDir: join(worktree, '.claude', 'skills', 'verify'), worktree, home });
    if (ledger.unclosedEntries().length === 0) continue;
    try {
      await stopRecorders(ledger, runner);
      const deleted = await deleteIdentities(ledger, clerk());
      for (const entry of ledger.unclosedEntries()) ledger.append({ id: newEntryId(), kind: 'done', ref: entry.id });
      progress(`reap    ledger of ${worktree}  (worktree is gone)  deleted ${deleted.users} users, ${deleted.organizations} organizations`);
    } catch (error) {
      progress(`reap    ledger of ${worktree} left open: ${(error as Error).message}`);
    }
  }
}
