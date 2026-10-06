import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { standingInstances } from '../testing/fake-instances.ts';
import { describe, it } from 'node:test';
import { doctor, down, up, type Deps } from '../src/core/verbs.ts';
import { openWorkspace } from '../src/core/workspace.ts';
import { newEntryId } from '../src/core/workspace.ts';
import { VerifyFailure, type BuiltApp, type DeviceBackend, type HostAdapter, type RemoteLease, type RunId, type TestEmail } from '../src/core/types.ts';

/** A host whose only usable backend builds the app itself, the way the remote backend does. */
function setup() {
  const dir = mkdtempSync(join(tmpdir(), 'verify-remote-flow-'));
  execFileSync('git', ['init', '-q'], { cwd: dir });
  writeFileSync(join(dir, 'app.swift'), 'one');
  const events: string[] = [];
  const progress: string[] = [];
  const deleted: string[] = [];
  let sha = 'a'.repeat(40);
  let health: 'held' | 'lost' = 'held';
  let pushed = true;
  let stuck = false;
  const lease = (session: string): RemoteLease => ({ backend: 'remote', provider: 'github-actions', platform: 'ios', session, providerRef: '1', baseUrl: 'https://x.trycloudflare.com', tokenFile: join(dir, 'token'), deviceId: 'UDID', deviceName: 'iPhone Air', runner: 'mac-runner', expiresAt: '2026-10-05T01:00:00Z', builtSha: null, acquiredAt: '', installedBuild: null });
  let sessions = 0;
  const remote = {
    kind: 'remote',
    platform: 'ios',
    requirement: 'a pushed branch',
    availability: () => ({ usable: true, why: 'a device on a runner' }),
    async sourceCommit(): Promise<string> {
      if (!pushed) throw new VerifyFailure('BUILD_FAILED', 'GitHub does not have HEAD', 'git push, then rerun');
      return sha;
    },
    reapable: async () => [],
    check: async () => health,
    async acquire(request: { app: BuiltApp; runner?: string }) {
      sessions += 1;
      events.push(`acquire sha=${request.app.sourceSha?.slice(0, 1)} runner=${request.runner ?? 'default'}`);
      return { ...lease(`s${sessions}`), ...(request.runner === undefined ? {} : { runner: request.runner }) };
    },
    async install(held: RemoteLease, app: BuiltApp): Promise<RemoteLease> {
      events.push(`install ${held.session} sha=${app.sourceSha?.slice(0, 1)}`);
      return { ...held, builtSha: app.sourceSha };
    },
    async release(held: RemoteLease) {
      events.push(`release ${held.session}`);
      if (stuck) throw new VerifyFailure('NOT_READY', 'the run would not end', 'cancel it');
    },
    describe: (held: RemoteLease) => `${held.deviceName} on ${held.runner}`,
    doctorChecks: async () => ({ toolchain: [], device: [] }),
  } as unknown as DeviceBackend;
  const local = { kind: 'local', platform: 'ios', requirement: 'a Mac with Xcode', availability: () => ({ usable: false, why: 'the iOS simulator needs macOS and this machine runs linux' }) } as unknown as DeviceBackend;
  const host = {
    repo: 'clerk-ios',
    platforms: ['ios'],
    backends: [local, remote],
    features: [],
    keysFile: '.keys.json',
    appId: () => 'com.clerk.E2EHost',
    entry: () => ({ kind: 'binary' }),
    buildInputs: () => ['app.swift'],
    buildSources: () => [],
    build: async () => {
      throw new Error('a backend that builds must never trigger a local build');
    },
  } as unknown as HostAdapter;
  const workspace = openWorkspace({ skillDir: dir, worktree: dir, home: join(dir, 'home') });
  const deps: Deps = {
    host,
    workspace,
    runner: async () => ({ code: 1, stdout: '', stderr: '' }),
    env: {},
    progress: (line: string) => void progress.push(line),
    instances: standingInstances({ clerk: () => ({ deleteByEmail: async (email) => (deleted.push(email), { users: 1, organizations: 0 }) }) }),
  };
  const edit = (text: string, newSha: string) => {
    writeFileSync(join(dir, 'app.swift'), text);
    sha = newSha.repeat(40);
  };
  return { deps, events, progress, edit, lose: () => (health = 'lost'), unpush: () => (pushed = false), stick: () => (stuck = true), deleted };
}

describe('lease flow with a backend that builds the app', () => {
  it('falls through to remote on a machine that cannot run the device, says why, and builds nothing locally', async () => {
    const { deps, events, progress } = setup();
    const result = await up(deps, { verb: 'up', waitSeconds: 0 });
    assert.equal(progress[0], 'backend remote  local is out: the iOS simulator needs macOS and this machine runs linux; a device on a runner');
    assert.deepEqual(events, ['acquire sha=a runner=default', 'install s1 sha=a']);
    assert.equal(result.leases[0]!.backend, 'remote');
    assert.equal(result.builds[0]!.source, 'github-actions');
    const held = deps.workspace.readLease('ios') as RemoteLease;
    assert.equal(held.builtSha, 'a'.repeat(40));
    assert.equal(held.installedBuild, result.builds[0]!.key);
  });

  it('rebuilds on the held session after an edit instead of leasing a new one', async () => {
    const { deps, events, edit } = setup();
    await up(deps, { verb: 'up', waitSeconds: 0 });
    await up(deps, { verb: 'up', waitSeconds: 0 });
    assert.equal(events.length, 2, 'an unchanged tree neither leases nor installs again');
    edit('two', 'b');
    await up(deps, { verb: 'up', waitSeconds: 0 });
    assert.deepEqual(events.slice(2), ['install s1 sha=b']);
    assert.equal((deps.workspace.readLease('ios') as RemoteLease).builtSha, 'b'.repeat(40));
  });

  it('leases a new session when the held one has stopped itself', async () => {
    const { deps, events, progress, lose } = setup();
    await up(deps, { verb: 'up', waitSeconds: 0 });
    lose();
    const result = await up(deps, { verb: 'up', waitSeconds: 0 });
    assert.deepEqual(events.slice(2), ['release s1', 'acquire sha=a runner=default', 'install s2 sha=a']);
    assert.ok(progress.some((line) => line.startsWith('lost    iPhone Air on mac-runner')));
    assert.equal(result.leases[0]!.renewed, true);
  });

  it('passes --runner to the session and refuses a different label while a session is held', async () => {
    const { deps, events } = setup();
    await up(deps, { verb: 'up', runner: 'free-mac', waitSeconds: 0 });
    assert.equal(events[0], 'acquire sha=a runner=free-mac');
    await assert.rejects(up(deps, { verb: 'up', runner: 'other-mac', waitSeconds: 0 }), (error: VerifyFailure) => error.code === 'NOT_READY' && error.message.includes('free-mac'));
  });

  it('doctor reports the chosen backend and whether the session holds the current build', async () => {
    const { deps } = setup();
    const before = await doctor(deps, { verb: 'doctor', live: false });
    assert.deepEqual(before.backend, { ios: 'remote' });
    assert.match(before.checks.find((c) => c.id === 'backend')!.detail, /^remote  local is out:/);
    assert.equal(before.checks.find((c) => c.id === 'build')!.ok, false);
    assert.equal(before.checks.some((c) => c.id === 'agent-device-global'), false, 'a remote driver needs no global agent-device');
    await up(deps, { verb: 'up', waitSeconds: 0 });
    const after = await doctor(deps, { verb: 'doctor', live: false });
    assert.equal(after.checks.find((c) => c.id === 'build')!.ok, true);
    assert.match(after.checks.find((c) => c.id === 'build')!.detail, /commit aaaaaaaaaaaa/);
  });

  it('needs no push for a commit that leaves the app sources alone', async () => {
    const { deps, events, unpush } = setup();
    await up(deps, { verb: 'up', waitSeconds: 0 });
    unpush();
    await up(deps, { verb: 'up', waitSeconds: 0 });
    assert.equal(events.length, 2, 'the session already holds this build, so an unpushed spec or docs commit is fine');
  });

  it('still asks for a push once the app sources change', async () => {
    const { deps, edit, unpush } = setup();
    await up(deps, { verb: 'up', waitSeconds: 0 });
    edit('two', 'b');
    unpush();
    await assert.rejects(up(deps, { verb: 'up', waitSeconds: 0 }), (error: VerifyFailure) => error.code === 'BUILD_FAILED' && error.fix.startsWith('git push'));
  });

  it('down deletes the test users even when the session will not end, then reports the session', async () => {
    const { deps, stick, deleted } = setup();
    await up(deps, { verb: 'up', waitSeconds: 0 });
    deps.workspace.append({ id: newEntryId(), kind: 'identity', run: 'r20261005-000000-0000' as RunId, instance: 'with-email-codes', email: 'verify_x_1+clerk_test@example.com' as TestEmail });
    stick();
    await assert.rejects(down(deps, { verb: 'down', stale: false, dryRun: false }), (error: VerifyFailure) => error.message === 'the run would not end');
    assert.deepEqual(deleted, ['verify_x_1+clerk_test@example.com']);
    assert.ok(deps.workspace.readLease('ios') !== null, 'the lease stays so a later down can retry');
  });

  it('down releases the session', async () => {
    const { deps, events } = setup();
    await up(deps, { verb: 'up', waitSeconds: 0 });
    const result = await down(deps, { verb: 'down', stale: false, dryRun: false });
    assert.equal(events.at(-1), 'release s1');
    assert.equal(result.dryRun === false && result.released[0]!.device, 'iPhone Air on mac-runner');
    assert.equal(deps.workspace.readLease('ios'), null);
  });
});
