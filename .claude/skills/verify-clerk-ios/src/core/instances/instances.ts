import { existsSync, mkdirSync, readFileSync, readdirSync } from 'node:fs';
import { join, relative, sep } from 'node:path';
import { BACKEND_API_FIX, BACKEND_API_HOSTS, INSTANCE_REQUIREMENTS, createClerkBackends, frontendApiHost, isUnauthorized, type ClerkBackend, type StandingClerk } from '../clerk.ts';
import { currentProcess, isRunning, sleep as defaultSleep, type Runner } from '../exec.ts';
import { instancesWithKeys, keysFilePath, loadInstanceKeys, type InstanceKeys } from '../keys.ts';
import { deleteIdentities, pendingIdentities } from '../ledgers.ts';
import { count } from '../state.ts';
import { newEntryId, takeSlotLock, type Workspace } from '../workspace.ts';
import {
  DEFAULT_INSTANCE,
  INSTANCE_NAMES,
  NO_INSTANCE_FIX,
  VerifyFailure,
  type ApplicationView,
  type DeletionTarget,
  type DoctorCheck,
  type HostAdapter,
  type IdentityHome,
  type InstanceName,
  type InstanceSource,
  type InstanceView,
  type Json,
  type ProcessRef,
} from '../types.ts';
import { describeDifference, flattenEnvironment } from './definitions.ts';
import { NoPlatformCredential, createPlatform, describeCredential, type Platform } from './platform.ts';
import { STANDARD_FILE, SettingsRefused, canonical, declaredIn, expectedEnvironment, legacyUse, settingsOf, standingStandIn, type SettingsGroup } from './settings.ts';
import { createThrowaway, openApplications, type HeldApplication, type Throwaway } from './throwaway.ts';

export interface InstanceChoice {
  readonly source: InstanceSource;
  /** Why this source, for the `instances` line `doctor`, `up`, and `run` print. */
  readonly why: string;
}

export interface FinishedInstances {
  readonly applications: readonly ApplicationView[];
  readonly users: number;
  readonly organizations: number;
}

/** The instance one group of a run drives on, from `apply` until `release`. */
export interface AppliedInstance {
  readonly keys: InstanceKeys;
  readonly instance: { readonly source: 'throwaway'; readonly id: string; readonly name: string } | { readonly source: 'standing'; readonly instance: InstanceName };
  /** How long the config PATCH for this group took, or null when none was sent. */
  readonly changed: { readonly answeredMs: number; readonly visibleMs: number } | null;
  /** Reads the public environment once and says whether the settings still hold. Throws when it cannot be read. Call it before `release`. */
  stillApplied(): Promise<boolean>;
  /** After it, `keys` and `clerk` of `Instances` throw until the next `apply`. */
  release(): Promise<void>;
}

export interface Instances {
  /**
   * Decides, once per process, where instances come from: applications this worktree creates and deletes, or the three
   * standing instances. With nothing held yet it also proves the credential works, so a caller can fail before it
   * starts anything that costs money.
   */
  choice(): Promise<InstanceChoice>;
  /** The key of the settings recorded for an application this worktree holds, read from disk with no request. Null when none is recorded. */
  recordedKey(): string | null;
  /**
   * Makes sure the worktree holds a usable throwaway application, creating one on the standard settings when it holds
   * none. `willChange` says the caller will apply other settings than the recorded ones, so the Platform credential
   * is opened here, before a device is leased, and never in the middle of a run.
   */
  ensure(options: { readonly willChange: boolean }, progress: (line: string) => void): Promise<{ readonly choice: InstanceChoice; readonly instances: readonly InstanceView[] }>;
  /** Puts an instance on the group's settings for this process to drive on. One at a time: release it before the next. */
  apply(group: SettingsGroup, progress: (line: string) => void): Promise<AppliedInstance>;
  /** Of the applied instance. Throws when nothing is applied. */
  keys(): InstanceKeys & { readonly home: IdentityHome };
  /** Of the applied instance. Throws when nothing is applied. */
  clerk(): ClerkBackend;
  /**
   * Finishes what a ledger still holds: deletes its throwaway applications unless `keepApplications`, closes the
   * identities that lived in them, and deletes the users an earlier run left in the standing instances.
   */
  finish(ledger: Workspace, options: { readonly keepApplications: boolean }, progress: (line: string) => void): Promise<FinishedInstances>;
  /** What `finish` would delete, read from the ledger and the standing instances with no Platform API call. */
  preview(ledger: Workspace): Promise<readonly DeletionTarget[]>;
  doctorChecks(options: { readonly live: boolean }, progress: (line: string) => void): Promise<readonly DoctorCheck[]>;
}

export interface InstancesDeps {
  readonly host: HostAdapter;
  readonly workspace: Workspace;
  readonly env: Readonly<Record<string, string | undefined>>;
  readonly runner: Runner;
  readonly progress: (line: string) => void;
  readonly fetch?: typeof fetch;
  readonly sleep?: (ms: number) => Promise<void>;
  readonly now?: () => number;
  readonly drivers?: { readonly self: ProcessRef; readonly isRunning: (driver: ProcessRef) => boolean };
}

function check(id: DoctorCheck['id'], ok: boolean, detail: string, fix: string): DoctorCheck {
  return ok ? { id, ok, detail } : { id, ok, detail, fix };
}

function specFiles(dir: string): string[] {
  if (!existsSync(dir)) return [];
  return readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const path = join(dir, entry.name);
    return entry.isDirectory() ? specFiles(path) : entry.name.endsWith('.e2e.ts') ? [path] : [];
  });
}

const FRESH_KEY_SECONDS = 10;

export function createInstances(deps: InstancesDeps): Instances {
  const { host, workspace, env } = deps;
  const sleep = deps.sleep ?? defaultSleep;
  const request = deps.fetch ?? fetch;
  const backends = createClerkBackends(deps.fetch, deps.progress);
  const platform: Platform = createPlatform({ env, runner: deps.runner, progress: deps.progress, ...(deps.fetch === undefined ? {} : { fetch: deps.fetch }), sleep, ...(deps.now === undefined ? {} : { now: deps.now }) });
  const throwaway: Throwaway = createThrowaway({
    workspace,
    platform,
    clerk: backends,
    env,
    self: deps.drivers?.self ?? currentProcess(),
    isRunning: deps.drivers?.isRunning ?? isRunning,
    ...(deps.fetch === undefined ? {} : { fetch: deps.fetch }),
    sleep,
    ...(deps.now === undefined ? {} : { now: deps.now }),
  });
  const standingKeys = (instance: InstanceName): InstanceKeys => loadInstanceKeys(host, instance, workspace.worktree, env);
  const standingClerk: StandingClerk = (instance) => backends(() => standingKeys(instance));
  let choosing: Promise<InstanceChoice> | undefined;
  let applied: (AppliedInstance & { readonly home: IdentityHome }) | undefined;

  const current = (): AppliedInstance & { readonly home: IdentityHome } => {
    if (applied === undefined) throw new VerifyFailure('NOT_READY', 'no instance is applied: a spec asked for a user or a launch outside the part of a run that drives the device', 'report this as a verify bug');
    return applied;
  };
  const appliedClerk = backends(() => current().keys);

  const wanted = env.VERIFY_INSTANCES?.trim() || undefined;
  const inline = (env.CLERK_TEST_KEYS_JSON ?? '').trim() !== '';
  /** With neither variable set, the instances are standing only because this machine has no Platform credential. */
  const toThrowaway = `run on a throwaway instance: ${inline || wanted === 'standing' ? 'unset CLERK_TEST_KEYS_JSON and VERIFY_INSTANCES=standing' : '`VERIFY_INSTANCES=throwaway {cli} doctor` prints what credential this machine is missing'}`;

  async function choose(): Promise<InstanceChoice> {
    if (wanted !== undefined && wanted !== 'standing' && wanted !== 'throwaway') throw new VerifyFailure('USAGE', `VERIFY_INSTANCES=${wanted} is not standing or throwaway`, 'unset VERIFY_INSTANCES, or set it to standing or throwaway');
    const holding = openApplications(workspace).length > 0;
    const standing = (why: string): InstanceChoice => {
      if (holding) throw new VerifyFailure('NOT_READY', `this worktree holds throwaway instances, and ${why} asks for the standing ones`, '{cli} down, then rerun');
      return { source: 'standing', why };
    };
    if (inline && wanted === 'throwaway') throw new VerifyFailure('USAGE', 'CLERK_TEST_KEYS_JSON names standing instances and VERIFY_INSTANCES=throwaway asks for throwaway ones', 'unset one of the two');
    if (inline) return standing('CLERK_TEST_KEYS_JSON');
    if (wanted === 'standing') return standing('VERIFY_INSTANCES=standing');
    if (holding) return { source: 'throwaway', why: 'this worktree already holds throwaway instances' };
    try {
      const open = await platform.open();
      return { source: 'throwaway', why: `${describeCredential(open.credential)} reaches the verification workspace ${open.workspace}` };
    } catch (error) {
      if (wanted === 'throwaway' || !(error instanceof NoPlatformCredential) || !existsSync(keysFilePath(host, workspace.worktree))) throw error;
      return { source: 'standing', why: `${host.keysFile} is in the main worktree and ${error.message}. To get throwaway instances: ${error.setUp}` };
    }
  }

  const choice = (): Promise<InstanceChoice> => (choosing ??= choose());

  async function locked<T>(fn: () => T | Promise<T>): Promise<T> {
    mkdirSync(join(workspace.root, 'locks'), { recursive: true });
    const release = await takeSlotLock(
      join(workspace.root, 'locks', 'instances'),
      Number.POSITIVE_INFINITY,
      () => new VerifyFailure('NOT_READY', 'unreachable', ''),
      (owner) => deps.progress(`wait    another {cli} in this worktree (pid ${owner.pid}) is creating, changing, or deleting instances; waiting for it, with no time limit`),
    );
    try {
      return await fn();
    } finally {
      release();
    }
  }

  /** A key from a create answer can take a moment to be accepted, so a 401 is retried briefly before it counts. */
  async function apiHost(keys: InstanceKeys): Promise<string> {
    const clerk = backends(() => keys);
    for (let second = 0; ; second += 1) {
      try {
        return await clerk.apiHost();
      } catch (error) {
        if (!isUnauthorized(error) || second >= FRESH_KEY_SECONDS) throw error;
        await sleep(1000);
      }
    }
  }

  /** The first call with a new instance's own key is where a replaced Authorization header shows. */
  async function ownKeyAccepted(id: string, keys: InstanceKeys, progress: (line: string) => void): Promise<void> {
    const used = await apiHost(keys).catch((error: unknown) => {
      throw new VerifyFailure('NOT_READY', `neither ${BACKEND_API_HOSTS.join(' nor ')} accepts the own secret key of ${id}: ${(error as Error).message}`, `${BACKEND_API_FIX}; \`{cli} down\` deletes the instance`);
    });
    progress(`clerk   Backend API on ${used}`);
  }

  async function standingChecks(): Promise<readonly DoctorCheck[]> {
    const checks: DoctorCheck[] = [];
    let keyed: readonly InstanceName[] = [];
    try {
      const found = instancesWithKeys(host, workspace.worktree, env);
      keyed = found.present;
      checks.push(check('keys', found.missing.length === 0, found.missing.length === 0 ? `${found.present.join(', ')} (pk and sk present)` : `missing pk or sk for ${found.missing.join(', ')}`, `add ${found.missing.join(', ')} to ${host.keysFile} in the main worktree`));
    } catch (error) {
      checks.push(check('keys', false, (error as Error).message, error instanceof VerifyFailure ? error.fix : `add ${host.keysFile} to the main worktree`));
    }
    for (const instance of INSTANCE_NAMES) {
      const id = `instance:${instance}` as const;
      if (!keyed.includes(instance)) {
        checks.push(check(id, false, 'no keys', 'see the keys check'));
        continue;
      }
      try {
        const found = await standingClerk(instance).settings();
        const want = INSTANCE_REQUIREMENTS[instance];
        const missing = [...want.strategies.filter((s) => !found.strategies.includes(s)), ...(want.organizations && !found.organizations ? ['organizations'] : [])];
        const wanted = [...want.strategies, ...(want.organizations ? ['organizations'] : [])];
        checks.push(check(id, missing.length === 0, missing.length === 0 ? `${wanted.join(', ')} enabled` : `${missing.join(', ')} not enabled`, `enable ${missing.join(', ')} on the ${instance} instance in the Clerk dashboard`));
      } catch (error) {
        checks.push(check(id, false, `FAPI environment failed: ${(error as Error).message}`, 'check the network and the instance pk'));
      }
    }
    return checks;
  }

  function declarations(): { readonly declaring: number } | { readonly refused: VerifyFailure } {
    let declaring = 0;
    for (const file of specFiles(join(workspace.skillDir, 'specs')).sort()) {
      const path = relative(workspace.skillDir, file).split(sep).join('/');
      const source = readFileSync(file, 'utf8');
      const legacy = legacyUse(source);
      if (legacy !== null) return { refused: new VerifyFailure('USAGE', `${path} still has ${legacy}`, NO_INSTANCE_FIX) };
      try {
        if (settingsOf(declaredIn(source, path), path).declared !== null) declaring += 1;
      } catch (error) {
        if (!(error instanceof VerifyFailure)) throw error;
        return { refused: error };
      }
    }
    return { declaring };
  }

  async function settingsCheck(): Promise<DoctorCheck> {
    const details: string[] = [];
    const fixes: string[] = [];
    try {
      const inspected = await throwaway.inspect();
      if (inspected.length === 0) details.push(`none created yet; up creates one application from ${STANDARD_FILE}`);
      for (const { application, found } of inspected) {
        const { id, settings } = application;
        if (found === 'gone') {
          details.push(`Clerk no longer serves ${id}`);
          fixes.push('{cli} up creates a new application');
        } else if (settings === null) {
          details.push(`${id} has no settings recorded`);
          fixes.push('{cli} up returns it to the standard settings');
        } else if (found.differing.length > 0) {
          details.push(`${id} is recorded as on ${settings.label} and shows ${found.differing.slice(0, 5).map((d) => describeDifference(d, 'those settings expect')).join('; ')}`);
          fixes.push('{cli} up returns it to the standard settings');
        } else {
          details.push(
            [
              `${id} is on ${settings.label}${settings.askedBy === null ? '' : `, which ${settings.askedBy} asked for`}`,
              `${found.compared} settings match ${STANDARD_FILE}${settings.declared === null ? '' : ' with that declaration'}`,
              ...(found.drifted.length === 0 ? [] : [`${count(found.drifted.length, 'setting')} no spec depends on differ from the file (${found.drifted.slice(0, 4).map((d) => describeDifference(d)).join('; ')})`]),
              ...(found.unknown.length === 0 ? [] : [`Clerk reports ${count(found.unknown.length, 'setting')} the file does not list (${found.unknown.slice(0, 4).join(', ')})`]),
            ].join('; '),
          );
        }
      }
    } catch (error) {
      details.push(`could not read an environment: ${(error as Error).message}`);
      fixes.push('check network access to *.clerk.accounts.dev');
    }
    const scanned = declarations();
    if ('refused' in scanned) {
      details.push(scanned.refused.message);
      fixes.push(scanned.refused.fix);
    } else {
      details.push(scanned.declaring === 1 ? '1 spec file declares settings' : `${scanned.declaring} spec files declare settings`);
    }
    return check('settings', fixes.length === 0, details.join('; '), fixes.join('; '));
  }

  async function apiCheck(application: HeldApplication | null): Promise<DoctorCheck> {
    const [first, second] = BACKEND_API_HOSTS;
    if (application === null) return check('clerk-api', true, `not observed yet: the first call with an instance's own key decides between ${first} and ${second}`, '');
    try {
      const used = await apiHost(application.keys);
      return check('clerk-api', true, used === first ? `${first} accepts the own key of ${application.id}` : `${second} is in use: ${first} answered 401 to the own key of ${application.id}, so something replaces the Authorization header there`, '');
    } catch (error) {
      return check('clerk-api', false, `neither ${first} nor ${second} accepts the own key of ${application.id}: ${(error as Error).message}`, BACKEND_API_FIX);
    }
  }

  async function ensure(options: { readonly willChange: boolean }, progress: (line: string) => void): Promise<{ readonly choice: InstanceChoice; readonly instances: readonly InstanceView[] }> {
    const made = await choice();
    progress(`instances ${made.source}  ${made.why}`);
    if (made.source === 'standing') return { choice: made, instances: [{ source: 'standing', instance: DEFAULT_INSTANCE }] };
    const up = await throwaway.ensure(options, progress);
    if (up.created !== null) await ownKeyAccepted(up.created.id, up.created.keys, progress);
    return { choice: made, instances: up.views };
  }

  async function environmentOf(instance: InstanceName, keys: InstanceKeys): Promise<Readonly<Record<string, Json>>> {
    const response = await request(`https://${frontendApiHost(keys.pk)}/v1/environment`, { signal: AbortSignal.timeout(15_000) });
    if (!response.ok) throw new VerifyFailure('NOT_READY', `the Frontend API of the standing instance ${instance} answered ${response.status}`, 'check the network and the instance pk');
    return flattenEnvironment((await response.json()) as Json);
  }

  /** A standing instance cannot be changed, so a declaration is checked against the one that already has it. */
  async function applyStanding(group: SettingsGroup, progress: (line: string) => void): Promise<AppliedInstance & { readonly home: IdentityHome }> {
    const { settings } = group;
    const instance = standingStandIn(settings);
    if (instance === null) {
      throw new SettingsRefused(`${settings.askedBy} declares ${settings.label}, and no standing instance has those settings; a standing instance cannot be changed`, toThrowaway);
    }
    const keys = standingKeys(instance);
    const declared = Object.keys(settings.declared?.environment ?? {});
    const expected = expectedEnvironment(settings);
    const missing = async (): Promise<readonly string[]> => {
      if (declared.length === 0) return [];
      const live = await environmentOf(instance, keys);
      return declared.flatMap((leaf) => (live[leaf] !== undefined && canonical(live[leaf]) === canonical(expected[leaf] ?? null) ? [] : [`${leaf} is ${live[leaf] === undefined ? 'absent' : JSON.stringify(live[leaf])} and the declaration expects ${JSON.stringify(expected[leaf])}`]));
    };
    const unmet = await missing();
    if (unmet.length > 0) {
      throw new SettingsRefused(`${settings.askedBy} declares ${settings.label}, and the standing instance ${instance} does not show it: ${unmet.join('; ')}`, `a standing instance cannot be changed: correct ${instance} in the Clerk dashboard, or ${toThrowaway}`);
    }
    progress(`settings ${settings.label}  on the standing instance ${instance}, which already has it`);
    return {
      keys,
      home: { instance },
      instance: { source: 'standing', instance },
      changed: null,
      stillApplied: async () => (await missing()).length === 0,
      release: async () => {
        applied = undefined;
      },
    };
  }

  async function applyThrowaway(group: SettingsGroup, progress: (line: string) => void): Promise<AppliedInstance & { readonly home: IdentityHome }> {
    const application = await locked(async () => {
      const made = await throwaway.apply(group, progress);
      if (made.created) await ownKeyAccepted(made.id, made.keys, progress);
      return made;
    });
    return {
      keys: application.keys,
      home: { application: application.name },
      instance: { source: 'throwaway', id: application.id, name: application.name },
      changed: application.changed,
      stillApplied: application.stillApplied,
      release: async () => {
        applied = undefined;
        await locked(application.release);
      },
    };
  }

  async function finish(ledger: Workspace, options: { readonly keepApplications: boolean }, progress: (line: string) => void): Promise<FinishedInstances> {
    const failures: unknown[] = [];
    let applications: readonly ApplicationView[] = [];
    if (!options.keepApplications) applications = await throwaway.finish(ledger, progress).catch((error: unknown) => (failures.push(error), []));
    for (const entry of ledger.unclosedEntries()) {
      if ((entry.kind === 'identity' || entry.kind === 'user') && entry.application !== undefined) ledger.append({ id: newEntryId(), kind: 'done', ref: entry.id });
    }
    const deleted = await deleteIdentities(ledger, standingClerk).catch((error: unknown) => (failures.push(error), { users: 0, organizations: 0 }));
    if (failures.length > 0) throw failures[0];
    return { applications, ...deleted };
  }

  /** One lock for the whole probe, so it can only ever delete the application it created itself. */
  function liveCheck(progress: (line: string) => void): Promise<readonly DoctorCheck[]> {
    return locked(async () => {
      const held = throwaway.held();
      if (held.length > 0) {
        return [await apiCheck(held[0]!), await settingsCheck(), check('live-instance', true, `not run: this worktree already holds ${held.map((h) => h.id).join(', ')}, which the checks above read`, '')];
      }
      const started = Date.now();
      try {
        const up = await ensure({ willChange: false }, progress);
        const api = await apiCheck(throwaway.held()[0] ?? null);
        const inspected = await settingsCheck();
        const made = up.instances[0];
        const finished = await finish(workspace, { keepApplications: false }, progress);
        const what = made?.source === 'throwaway' ? `${made.id} (${made.name})` : 'an application';
        return [api, inspected, check('live-instance', api.ok, `created ${what}, configured it, compared its environment, and deleted it (${count(finished.applications.length, 'application')} gone from the list) in ${Math.round((Date.now() - started) / 1000)}s`, BACKEND_API_FIX)];
      } catch (error) {
        const failure = error instanceof VerifyFailure ? error : new VerifyFailure('NOT_READY', (error as Error).message, '{cli} down deletes anything it left');
        await finish(workspace, { keepApplications: false }, progress).catch(() => undefined);
        return [check('live-instance', false, failure.message, failure.fix)];
      }
    });
  }

  return {
    choice,
    recordedKey: () => throwaway.held().find((application) => application.settings !== null)?.settings?.key ?? null,
    keys: () => {
      const { keys, home } = current();
      return { ...keys, home };
    },
    clerk: () => {
      current();
      return appliedClerk;
    },
    ensure: (options, progress) => locked(() => ensure(options, progress)),

    async apply(group, progress) {
      if (applied !== undefined) throw new Error('an instance is still applied: release it before applying the next group');
      applied = (await choice()).source === 'standing' ? await applyStanding(group, progress) : await applyThrowaway(group, progress);
      return applied;
    },

    // Another worktree's ledger shares nothing with this one's, so finishing it waits for no one.
    finish: (ledger, options, progress) => (ledger.root === workspace.root ? locked(() => finish(ledger, options, progress)) : finish(ledger, options, progress)),

    async preview(ledger) {
      const targets: DeletionTarget[] = openApplications(ledger).map((entry) => ({ kind: 'application', name: entry.name }));
      for (const identity of pendingIdentities(ledger.unclosedEntries())) {
        for (const owned of await standingClerk(identity.instance).previewDeleteByEmail(identity.email)) targets.push({ ...owned, instance: identity.instance });
      }
      return targets;
    },

    async doctorChecks(options, progress) {
      const failed = (error: unknown, prefix = ''): DoctorCheck => {
        const failure = error instanceof VerifyFailure ? error : new VerifyFailure('NOT_READY', (error as Error).message, 'run `{cli} doctor` again');
        return check('instances', false, `${prefix}${failure.message}`, failure.fix);
      };
      let made: InstanceChoice;
      try {
        made = await choice();
      } catch (error) {
        return [failed(error)];
      }
      if (made.source === 'standing') {
        // No Backend API call here: doctor has never written to or read users from the standing instances, which other repos share.
        const checks = await standingChecks();
        return [check('instances', true, `standing  ${made.why}`, ''), ...checks.slice(0, 1), await apiCheck(null), ...checks.slice(1)];
      }

      const held = throwaway.held();
      const holding = held.length === 0 ? 'none created yet' : held.map((h) => `${h.id} (${h.name}) on ${h.settings?.label ?? 'unknown settings'}`).join(', ');
      let reaches: DoctorCheck;
      try {
        // Also when instances are held: `down` will need the credential, and this is where a person learns it is gone.
        const open = await platform.open();
        reaches = check('instances', true, `throwaway  ${describeCredential(open.credential)} reaches the verification workspace ${open.workspace}; ${holding}`, '');
      } catch (error) {
        reaches = failed(error, `throwaway  ${holding}; `);
      }
      if (options.live && reaches.ok) return [reaches, ...(await liveCheck(progress))];
      return [reaches, await apiCheck(held[0] ?? null), await settingsCheck()];
    },
  };
}
