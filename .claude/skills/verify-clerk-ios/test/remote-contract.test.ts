import assert from 'node:assert/strict';
import { readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import net from 'node:net';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, it } from 'node:test';
import { agentDeviceFor } from '../src/core/agent-device.ts';
import { chooseEgress } from '../src/core/launch.mjs';
import { usedSecretValues } from '../src/core/secret.ts';
import type { ApiResponse, GitHub } from '../src/core/remote/github.ts';
import { connectThroughProxy, egressCheck, remoteDoctorChecks } from '../src/core/remote/preflight.ts';
import { RUN_TITLE, STEP, triggerBranch } from '../src/core/remote/protocol.ts';
import type { RemoteSettings } from '../src/core/remote/settings.ts';
import type { LocalLease, RemoteLease } from '../src/core/types.ts';

describe('the session workflow and the driver agree', () => {
  const workflow = readFileSync(join(import.meta.dirname, '..', '..', '..', '..', '.github', 'workflows', 'verify-remote.yml'), 'utf8');
  const names = [...workflow.matchAll(/^\s+- name: (.+)$/gm)].map((m) => m[1]!);
  const evaluated = (template: string, value: string) => template.replace(/\$\{\{[^}]+\}\}/, value);

  it('publishes the tunnel and the probe echo in step names the driver can read', () => {
    const tunnel = names.find((name) => name.startsWith('verify-remote tunnel'))!;
    assert.equal(STEP.tunnelPattern.exec(evaluated(tunnel, 'quick-fox.trycloudflare.com'))?.[1], 'quick-fox.trycloudflare.com');
    const probe = names.find((name) => name.startsWith('verify-remote probe'))!;
    assert.equal(STEP.probePattern.exec(evaluated(probe, '0123456789abcdef'))?.[1], '0123456789abcdef');
  });

  it('titles runs and filters trigger branches the way the driver looks for them', () => {
    const request = { owner: '0123456789ab', session: 'iosaaaaaa' };
    assert.match(workflow, /^run-name: verify-remote \$\{\{ inputs\.owner && format\('\{0\}\/\{1\}', inputs\.owner, inputs\.session\) \|\| github\.ref_name \}\}$/m);
    assert.deepEqual(RUN_TITLE.exec(`verify-remote ${request.owner}/${request.session}`)?.slice(1), [request.owner, request.session]);
    assert.match(workflow, /branches: \['verify-remote\/\*\*'\]/);
    assert.ok(triggerBranch(request).startsWith('verify-remote/'));
  });

  it('gives the agent the files and variables it waits on, and uploads nothing', () => {
    for (const needle of ['VERIFY_SESSION_REQUEST', 'VERIFY_SESSION_WORK', 'VERIFY_SESSION_DEVICE_ID', 'VERIFY_SESSION_DEVICE_MODULE', 'VERIFY_SESSION_CLOUDFLARED', '$WORK/tunnel', 'device-ready', '$VERIFY_SESSION_WORK/ended', 'persist-credentials: false']) {
      assert.ok(workflow.includes(needle), needle);
    }
    assert.equal(workflow.includes('upload-artifact'), false, 'a public artifact is where a sign-in ticket could leak');
  });
});

describe('agent-device calls', () => {
  it('points at the local device with no secret', () => {
    const lease = { backend: 'local', platform: 'ios', deviceId: 'UDID-1' } as LocalLease;
    assert.deepEqual(agentDeviceFor(lease), { selector: ['--platform', 'ios', '--udid', 'UDID-1'], env: {} });
  });

  it('points at a remote daemon and passes the bearer in the environment, registered for redaction', () => {
    const tokenFile = join(mkdtempSync(join(tmpdir(), 'verify-token-')), 'token');
    writeFileSync(tokenFile, 'e'.repeat(64));
    const lease = { backend: 'remote', platform: 'ios', deviceId: 'UDID-2', baseUrl: 'https://x.trycloudflare.com', tokenFile } as RemoteLease;
    const call = agentDeviceFor(lease);
    assert.deepEqual(call.selector, ['--platform', 'ios', '--udid', 'UDID-2', '--daemon-base-url', 'https://x.trycloudflare.com/agent-device']);
    assert.deepEqual(call.env, { AGENT_DEVICE_DAEMON_AUTH_TOKEN: 'e'.repeat(64) });
    assert.ok(usedSecretValues().includes('e'.repeat(64)));
  });
});

describe('choosing between a direct connection and HTTPS_PROXY', () => {
  it('keeps a Mac with a debugging proxy exported on its direct connection', () => {
    assert.equal(chooseEgress({ proxyListens: true, directConnects: true, tokenStatusDirect: null }).proxy, false);
    assert.equal(chooseEgress({ proxyListens: true, directConnects: true, tokenStatusDirect: 200 }).proxy, false);
    assert.equal(chooseEgress({ proxyListens: false, directConnects: true, tokenStatusDirect: null }).proxy, false);
  });

  it('uses the proxy in a sandbox whose token only works through it, although a direct connection opens', () => {
    const choice = chooseEgress({ proxyListens: true, directConnects: true, tokenStatusDirect: 401 });
    assert.equal(choice.proxy, true);
    assert.match(choice.why, /rejects this machine's token on a direct connection/);
  });

  it('uses the proxy when it is the only way out', () => {
    assert.equal(chooseEgress({ proxyListens: true, directConnects: false, tokenStatusDirect: null }).proxy, true);
    assert.equal(chooseEgress({ proxyListens: true, directConnects: true, tokenStatusDirect: 0 }).proxy, true);
  });
});

describe('egress checks', () => {
  async function proxyAnswering(line: string): Promise<{ url: URL; close: () => void }> {
    const server = net.createServer((socket) => socket.once('data', () => socket.end(`${line}\r\n\r\n`)));
    await new Promise<void>((done) => server.listen(0, '127.0.0.1', done));
    return { url: new URL(`http://127.0.0.1:${(server.address() as net.AddressInfo).port}`), close: () => server.close() };
  }

  it('reports a refused CONNECT as blocked, with the proxy status line and the fix', async () => {
    const proxy = await proxyAnswering('HTTP/1.1 403 Forbidden');
    try {
      assert.deepEqual(await connectThroughProxy(proxy.url, 'x.trycloudflare.com'), { status: 403, line: 'HTTP/1.1 403 Forbidden' });
      const check = await egressCheck('tunnel-egress', 'x.trycloudflare.com', { HTTPS_PROXY: proxy.url.href, NODE_USE_ENV_PROXY: '1' }, 'allow the host');
      assert.equal(check.ok, false);
      assert.match(check.detail, /^blocked: the proxy at 127\.0\.0\.1:\d+ answered the CONNECT to x\.trycloudflare\.com with "HTTP\/1\.1 403 Forbidden"$/);
      assert.equal(check.fix, 'allow the host');
    } finally {
      proxy.close();
    }
  });

  it('says so when the proxy itself is unreachable', async () => {
    assert.equal((await connectThroughProxy(new URL('http://127.0.0.1:9'), 'x.trycloudflare.com')).status, 0);
  });
});

describe('doctor for the remote backend', () => {
  const settings = (): RemoteSettings => ({ platform: 'ios', repo: 'clerk/clerk-ios', workflow: 'verify-remote.yml', sessionsDir: mkdtempSync(join(tmpdir(), 'verify-doctor-')), runner: 'paid-mac', plumbingRunner: 'ubuntu-latest', device: 'iPhone Air', idleMinutes: 15, capMinutes: 60, agentDevice: () => '0.21.18', requirement: '' });
  const answer = (status: number, json: unknown = {}, refusedWithToken?: string): ApiResponse => ({ status, json, headers: new Headers(), ...(refusedWithToken === undefined ? {} : { refusedWithToken }) });
  const offline = { HTTPS_PROXY: 'http://127.0.0.1:9', NODE_USE_ENV_PROXY: '1' };
  const git = (pushFails: boolean) => async (command: string, args: readonly string[]) =>
    command === 'git' && args[0] === 'push' && pushFails
      ? { code: 128, stdout: '', stderr: "remote: the app has no access to this repository\nfatal: unable to access 'https://github.com/clerk/clerk-ios/': The requested URL returned error: 403\n" }
      : { code: 0, stdout: args.includes('--abbrev-ref') ? 'my-branch\n' : 'f'.repeat(40), stderr: '' };

  it('prints every check even when GitHub refuses everything, and says what each skipped check needed', async () => {
    const github: GitHub = { repo: 'clerk/clerk-ios', workflow: 'verify-remote.yml', tokenSource: 'GH_TOKEN', api: async () => answer(401, { message: 'Bad credentials' }) };
    const { device } = await remoteDoctorChecks(settings(), { env: offline, runner: git(true) }, async () => github, { live: true, worktree: '/w', progress: () => undefined });
    const byId = Object.fromEntries(device.map((c) => [c.id, c]));
    for (const id of ['git-fetch', 'git-push', 'github-rest', 'remote-commit', 'remote-trigger', 'remote-channel', 'tunnel-egress', 'clerk-egress', 'live-session', 'live-bearer', 'live-sim-health', 'live-daemon-health', 'live-stop']) {
      assert.ok(byId[id] !== undefined, `${id} is printed`);
    }
    assert.match(byId['git-push']!.detail, /the app has no access to this repository \| fatal: unable to access .* 403/);
    assert.match(byId['git-push']!.fix!, /Claude GitHub App is not installed on this repository/);
    assert.equal(byId['github-rest']!.ok, false);
    assert.equal(byId['remote-trigger']!.detail, 'not run: needs github-rest');
    assert.equal(byId['live-stop']!.detail, 'not run: needs github-rest');
  });

  it('keeps reading a public repository when the token is refused, and says the token is the problem', async () => {
    const github: GitHub = {
      repo: 'clerk/clerk-ios',
      workflow: 'verify-remote.yml',
      tokenSource: 'GH_TOKEN',
      api: async (method, path) => (method === 'POST' ? answer(401, { message: 'Bad credentials' }) : path.includes('/workflows/') ? answer(200, { workflow_runs: [] }) : answer(200, {}, '401 Bad credentials')),
    };
    const { device } = await remoteDoctorChecks(settings(), { env: offline, runner: git(true) }, async () => github, { live: false, worktree: '/w', progress: () => undefined });
    const byId = Object.fromEntries(device.map((c) => [c.id, c]));
    assert.equal(byId['github-rest']!.ok, true);
    assert.match(byId['github-rest']!.detail, /repository 200 without the token \(with it: 401 Bad credentials\).*GitHub refuses this machine's token/);
    assert.equal(byId['remote-commit']!.ok, true);
    assert.equal(byId['remote-trigger']!.ok, false);
    assert.match(byId['remote-trigger']!.detail, /workflow_dispatch was refused \(401 Bad credentials\) and pushing .* failed: the app has no access/);
    assert.match(byId['remote-trigger']!.fix!, /Claude GitHub App/);
    assert.equal(byId['remote-channel']!.detail, 'not run: needs remote-trigger (no run was started)');
  });

  it('does not push a probe for a HEAD that GitHub does not have', async () => {
    const calls: string[] = [];
    const github: GitHub = { repo: 'clerk/clerk-ios', workflow: 'verify-remote.yml', tokenSource: 'gh', api: async (method, path) => (calls.push(`${method} ${path}`), path.startsWith('/commits/') ? answer(422) : answer(200, { workflow_runs: [] })) };
    const { device } = await remoteDoctorChecks(settings(), { env: offline, runner: git(false) }, async () => github, { live: false, worktree: '/w', progress: () => undefined });
    assert.equal(device.find((c) => c.id === 'remote-trigger')!.detail, 'not run: needs remote-commit (the probe must not push a commit you have not pushed)');
    assert.equal(calls.some((call) => call.startsWith('POST')), false);
  });
});

