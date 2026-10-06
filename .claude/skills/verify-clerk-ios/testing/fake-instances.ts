import type { ClerkBackend, StandingClerk } from '../src/core/clerk.ts';
import type { InstanceKeys } from '../src/core/keys.ts';
import type { Instances } from '../src/core/instances/instances.ts';
import { standingStandIn } from '../src/core/instances/settings.ts';
import { deleteIdentities, pendingIdentities } from '../src/core/ledgers.ts';
import { DEFAULT_INSTANCE, type InstanceName } from '../src/core/types.ts';

export interface FakeStanding {
  /** A method a test does not give throws when something calls it. */
  readonly clerk?: (instance: InstanceName) => Partial<ClerkBackend>;
  /** Present for a test that drives a run: the keys a group's stand-in has. */
  readonly keys?: (instance: InstanceName) => InstanceKeys;
}

/** What a worktree on the three standing instances sees, with `clerk` in place of their Backend API. */
export function standingInstances(fake: FakeStanding = {}): Instances {
  const clerk: StandingClerk = (instance) => (fake.clerk?.(instance) ?? {}) as ClerkBackend;
  let applied: InstanceName | undefined;
  const current = (): InstanceName => {
    if (applied === undefined) throw new Error('nothing is applied');
    return applied;
  };
  return {
    choice: async () => ({ source: 'standing', why: 'a test' }),
    recordedKey: () => null,
    ensure: async () => ({ choice: { source: 'standing', why: 'a test' }, instances: [{ source: 'standing', instance: DEFAULT_INSTANCE }] }),
    apply: async (group) => {
      const instance = standingStandIn(group.settings);
      if (instance === null || fake.keys === undefined) throw new Error(`this test applies no settings, and something asked for ${group.settings.label}`);
      applied = instance;
      return {
        keys: fake.keys(instance),
        instance: { source: 'standing', instance },
        changed: null,
        stillApplied: async () => true,
        release: async () => {
          applied = undefined;
        },
      };
    },
    keys: () => {
      if (fake.keys === undefined) throw new Error('this test reads no keys, and something asked for them');
      return { ...fake.keys(current()), home: { instance: current() } };
    },
    clerk: () => clerk(current()),
    finish: async (ledger) => ({ applications: [], ...(await deleteIdentities(ledger, clerk)) }),
    preview: async (ledger) =>
      (await Promise.all(pendingIdentities(ledger.unclosedEntries()).map(async (identity) => (await clerk(identity.instance).previewDeleteByEmail(identity.email)).map((owned) => ({ ...owned, instance: identity.instance }))))).flat(),
    doctorChecks: async () => [],
  };
}
