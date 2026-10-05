import assert from 'node:assert/strict';
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { afterEach, describe, it } from 'node:test';
import { deviceCommand } from '../src/core/device-command.ts';
import { run } from '../src/core/exec.ts';
import { coreVersion } from '../src/core/manifest.ts';
import { remoteBackend } from '../src/core/remote/backend.ts';
import { deviceToolCommand, type SessionHealth } from '../src/core/remote/protocol.ts';
import { VerifyFailure, type LocalLease, type RemoteLease } from '../src/core/types.ts';

const realFetch = globalThis.fetch;
afterEach(() => void (globalThis.fetch = realFetch));

function remoteLease(platform: 'ios' | 'android'): RemoteLease {
  const tokenFile = join(mkdtempSync(join(tmpdir(), 'verify-command-')), 'token');
  writeFileSync(tokenFile, 'd'.repeat(64));
  return { backend: 'remote', provider: 'github-actions', platform, session: `${platform}abc123`, providerRef: '7', baseUrl: 'https://quick-fox.trycloudflare.com', tokenFile, deviceId: 'emulator-5554', deviceName: 'Pixel', runner: 'linux', expiresAt: new Date(Date.now() + 3_600_000).toISOString(), builtSha: null, acquiredAt: '', installedBuild: null };
}

/** Stands in for the session's tunnel: records each request and answers with `reply`. */
function tunnel(reply: (path: string) => { status: number; body: unknown }): { readonly calls: { path: string; method: string; authorization: string | null; body: unknown }[] } {
  const calls: { path: string; method: string; authorization: string | null; body: unknown }[] = [];
  globalThis.fetch = (async (input: string | URL | Request, init?: RequestInit) => {
    const url = new URL(String(input));
    assert.equal(url.host, 'quick-fox.trycloudflare.com');
    calls.push({ path: url.pathname, method: init?.method ?? 'GET', authorization: new Headers(init?.headers).get('authorization'), body: typeof init?.body === 'string' ? JSON.parse(init.body) : null });
    const { status, body } = reply(url.pathname);
    return new Response(JSON.stringify(body), { status, headers: { 'content-type': 'application/json' } });
  }) as typeof fetch;
  return { calls };
}

describe('the device tool', () => {
  it('is adb on the device for shell and reverse, and nothing else', () => {
    assert.deepEqual(deviceToolCommand('android', 'emulator-5560', ['shell', 'am force-stop com.x']), { command: 'adb', args: ['-s', 'emulator-5560', 'shell', 'am force-stop com.x'] });
    assert.deepEqual(deviceToolCommand('android', 'emulator-5560', ['reverse', 'tcp:8081', 'tcp:8081'], '/sdk/adb')?.command, '/sdk/adb');
    for (const args of [['pull', '/sdcard/x', '/etc/x'], ['push', '/etc/passwd', '/sdcard/x'], ['emu', 'kill'], ['-s', 'other', 'shell'], []]) assert.equal(deviceToolCommand('android', 'emulator-5560', args), null, args.join(' '));
    assert.equal(deviceToolCommand('ios', 'UDID', ['shell', 'id']), null);
  });
});

describe('deviceCommand', () => {
  it('runs adb from the SDK on this machine for a local lease, with stdin', async () => {
    const sdk = mkdtempSync(join(tmpdir(), 'verify-sdk-'));
    const ran: unknown[] = [];
    const lease = { backend: 'local', platform: 'android', deviceId: 'emulator-5560' } as LocalLease;
    const runner: typeof run = async (command, args, options) => (ran.push([command, args, options?.input]), { code: 0, stdout: 'ok', stderr: '' });
    assert.deepEqual(await deviceCommand(lease, ['shell', 'cat > x'], { input: '<map/>', runner, env: { ANDROID_HOME: sdk } }), { code: 0, stdout: 'ok', stderr: '' });
    assert.deepEqual(ran, [['adb', ['-s', 'emulator-5560', 'shell', 'cat > x'], '<map/>']], 'an SDK with no adb falls back to PATH');
    mkdirSync(join(sdk, 'platform-tools'));
    writeFileSync(join(sdk, 'platform-tools', 'adb'), '');
    await deviceCommand(lease, ['shell', 'id'], { runner, env: { ANDROID_HOME: sdk } });
    assert.deepEqual(ran[1], [join(sdk, 'platform-tools', 'adb'), ['-s', 'emulator-5560', 'shell', 'id'], undefined]);
  });

  it('asks the session for a remote lease and sends the bearer only to the tunnel', async () => {
    const { calls } = tunnel(() => ({ status: 200, body: { code: 0, stdout: 'reversed', stderr: '' } }));
    const result = await deviceCommand(remoteLease('android'), ['reverse', 'tcp:8081', 'tcp:8081'], { input: 'x' });
    assert.equal(result.stdout, 'reversed');
    assert.deepEqual(calls, [{ path: '/__sim/device-command', method: 'POST', authorization: `Bearer ${'d'.repeat(64)}`, body: { args: ['reverse', 'tcp:8081', 'tcp:8081'], stdin: 'x' } }]);
  });

  it('refuses the same arguments for both kinds of lease, before anything runs', async () => {
    const { calls } = tunnel(() => ({ status: 200, body: {} }));
    for (const lease of [remoteLease('android'), { backend: 'local', platform: 'android', deviceId: 'emulator-5560' } as LocalLease, remoteLease('ios')]) {
      await assert.rejects(deviceCommand(lease, ['pull', '/sdcard/x', 'x'], { runner: async () => assert.fail('ran') }), (error: VerifyFailure) => error.code === 'UNSUPPORTED');
    }
    assert.equal(calls.length, 0);
  });

  it('reports a session that will not run the command', async () => {
    tunnel(() => ({ status: 404, body: { error: 'no route POST /device-command' } }));
    await assert.rejects(deviceCommand(remoteLease('android'), ['shell', 'id']), (error: VerifyFailure) => error.code === 'NOT_READY' && error.message.includes('404') && error.message.includes('no route'));
  });
});

describe('a session started from another core', () => {
  const health = (core: string | undefined): SessionHealth =>
    ({ ok: true, v: 1, session: 'androidabc123', core, platform: 'android', runner: 'linux', device: { id: 'emulator-5554', name: 'Pixel', ready: true }, daemon: true, build: { state: 'none' }, recording: false, silentSeconds: 0, idleSeconds: 900, capAt: '', ending: null }) as SessionHealth;
  const backend = () =>
    remoteBackend(
      { platform: 'android', repo: 'clerk/clerk-android', workflow: 'verify-remote.yml', sessionsDir: mkdtempSync(join(tmpdir(), 'verify-core-')), runner: 'linux', plumbingRunner: 'ubuntu-latest', device: 'Pixel', idleMinutes: 15, capMinutes: 60, agentDevice: () => '0.21.18', requirement: '' },
      { env: {}, runner: run, github: async () => assert.fail('a session that answers is not looked up at GitHub') },
    );

  it('is held when its agent has this checkout\'s core', async () => {
    tunnel(() => ({ status: 200, body: health(coreVersion()) }));
    assert.equal(await backend().check(remoteLease('android')), 'held');
  });

  it('is refused, not renewed, when its agent has another core, with the fix that gets both onto one commit', async () => {
    for (const core of ['0123456789ab', undefined]) {
      tunnel(() => ({ status: 200, body: health(core) }));
      await assert.rejects(backend().check(remoteLease('android')), (error: VerifyFailure) => error.code === 'NOT_READY' && error.message.includes(coreVersion()) && error.fix === 'commit and push the changes under src/core, then {cli} down and {cli} up');
    }
  });
});
