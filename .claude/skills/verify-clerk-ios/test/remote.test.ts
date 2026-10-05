import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { selectBackend } from '../src/core/devices.ts';
import type { ExecResult } from '../src/core/exec.ts';
import { publishedStep, startRun, type GitHub, type JobView } from '../src/core/remote/github.ts';
import { RUN_TITLE, RequestError, STEP, matchesToken, parseRequest, probeEcho, sha256Hex, triggerBranch, type SessionRequest } from '../src/core/remote/protocol.ts';
import { tunnelUrl } from '../src/core/remote/session.ts';
import { VerifyFailure, type DeviceBackend, type HostAdapter } from '../src/core/types.ts';

const token = 'a'.repeat(64);
const request: SessionRequest = {
  v: 1,
  session: 'ios12ab34',
  owner: '03e8a20b1d8e',
  mode: 'session',
  platform: 'ios',
  runner: 'blacksmith-6vcpu-macos-27',
  device: 'iPhone Air',
  sha: 'f'.repeat(40),
  idleMinutes: 15,
  capMinutes: 60,
  agentDevice: '0.21.18',
  tokenSha256: sha256Hex(token),
};

describe('session request', () => {
  it('round-trips a valid request and accepts no device and no commit', () => {
    assert.deepEqual(parseRequest(JSON.stringify(request)), request);
    assert.deepEqual(parseRequest(JSON.stringify({ ...request, device: null, sha: null })), { ...request, device: null, sha: null });
  });

  it('refuses anything a shell or a runs-on could misread', () => {
    const bad: Record<string, unknown>[] = [
      { runner: 'ubuntu-latest; curl evil' },
      { runner: '${{ secrets.X }}' },
      { device: 'iPhone"; rm -rf /' },
      { sha: 'main' },
      { session: '../x' },
      { owner: 'someone' },
      { capMinutes: 100000 },
      { idleMinutes: 0 },
      { idleMinutes: 61 },
      { mode: 'build' },
      { tokenSha256: token.slice(1) },
      { v: 2 },
    ];
    for (const change of bad) assert.throws(() => parseRequest(JSON.stringify({ ...request, ...change })), RequestError, JSON.stringify(change));
    assert.throws(() => parseRequest('docs: an ordinary commit message'), RequestError);
  });

  it('recognizes the bearer by its hash and nothing else', () => {
    assert.equal(matchesToken(request.tokenSha256, token), true);
    assert.equal(matchesToken(request.tokenSha256, `${token}x`), false);
    assert.equal(matchesToken(request.tokenSha256, request.tokenSha256), false);
  });

  it('titles both triggers so the owner and session can be read back', () => {
    assert.deepEqual(RUN_TITLE.exec(`verify-remote ${request.owner}/${request.session}`)?.slice(1), [request.owner, request.session]);
    assert.deepEqual(RUN_TITLE.exec(`verify-remote ${triggerBranch(request)}`)?.slice(1), [request.owner, request.session]);
    assert.equal(RUN_TITLE.exec('verify-remote mike/some-branch'), null);
  });
});

describe('the step-name channel', () => {
  const job = (steps: readonly string[]): JobView => ({ name: 'session', status: 'in_progress', conclusion: null, steps: steps.map((name) => ({ name, status: 'completed', conclusion: 'success' })) });

  it('reads the tunnel host and the probe echo, and reads nothing before the step has its value', () => {
    assert.equal(publishedStep([job(['Set up job', STEP.tunnel('quick-fox-jumps.trycloudflare.com')])], STEP.tunnelPattern), 'quick-fox-jumps.trycloudflare.com');
    assert.equal(publishedStep([job(['Set up job', 'verify-remote tunnel '])], STEP.tunnelPattern), null);
    assert.equal(publishedStep([job(['verify-remote tunnel ${{ steps.tunnel.outputs.host }}'])], STEP.tunnelPattern), null);
    assert.equal(publishedStep([job([STEP.probe(probeEcho(request))])], STEP.probePattern), probeEcho(request));
  });

  it('refuses to send the bearer to a host outside the tunnel domain', () => {
    assert.equal(tunnelUrl('quick-fox-jumps.trycloudflare.com'), 'https://quick-fox-jumps.trycloudflare.com');
    for (const host of ['evil.example.com', 'trycloudflare.com.evil.example', 'x.trycloudflare.com:8443', 'x.trycloudflare.com/@evil']) {
      assert.throws(() => tunnelUrl(host), VerifyFailure, host);
    }
  });
});

describe('starting a run', () => {
  function fakeGitHub(dispatchStatus: number, runs: readonly { id: number; display_title: string }[]): { github: GitHub; calls: string[] } {
    const calls: string[] = [];
    const github: GitHub = {
      repo: 'clerk/clerk-ios',
      workflow: 'verify-remote.yml',
      tokenSource: 'none',
      async api(method, path) {
        calls.push(`${method} ${path}`);
        if (path.endsWith('/dispatches')) return { status: dispatchStatus, json: dispatchStatus === 200 ? { workflow_run_id: 41 } : { message: 'Resource not accessible by integration' }, headers: new Headers() };
        return { status: 200, json: { workflow_runs: runs }, headers: new Headers() };
      },
    };
    return { github, calls };
  }
  const ok = (stdout = ''): ExecResult => ({ code: 0, stdout, stderr: '' });

  it('uses the run id a dispatch returns and never touches git', async () => {
    const { github } = fakeGitHub(200, []);
    const git: string[] = [];
    const started = await startRun(github, request, { ref: 'mike/branch', worktree: '/w', runner: async (_c, args) => (git.push(args.join(' ')), ok()) });
    assert.deepEqual(started, { runId: '41', trigger: 'dispatch', dispatchRefused: null });
    assert.deepEqual(git, []);
  });

  it('falls back to pushing a request commit when dispatch is refused', async () => {
    const { github, calls } = fakeGitHub(403, [{ id: 77, display_title: `verify-remote ${triggerBranch(request)}` }]);
    const git: string[][] = [];
    const started = await startRun(github, request, {
      ref: 'mike/branch',
      worktree: '/w',
      runner: async (_c, args) => {
        git.push([...args]);
        return ok(args.includes('commit-tree') ? 'c0ffee\n' : 'tree1\n');
      },
    });
    assert.deepEqual(started, { runId: '77', trigger: 'push', dispatchRefused: '403 Resource not accessible by integration' });
    const commit = git.find((args) => args.includes('commit-tree'))!;
    assert.deepEqual(parseRequest(commit.at(-1)!), request);
    assert.deepEqual(git.at(-1), ['push', '--quiet', 'origin', `c0ffee:refs/heads/${triggerBranch(request)}`]);
    assert.ok(calls.some((call) => call.includes(`branch=${encodeURIComponent(triggerBranch(request))}`)));
  });

  it('names both refusals when neither trigger works', async () => {
    const { github } = fakeGitHub(403, []);
    await assert.rejects(
      startRun(github, request, { ref: 'b', worktree: '/w', runner: async (_c, args) => (args[0] === 'push' ? { code: 1, stdout: '', stderr: 'remote: denied' } : ok('x\n')) }),
      (error: VerifyFailure) => error.code === 'NOT_READY' && error.message.includes('403') && error.message.includes('remote: denied') && error.fix.includes('verify-remote/*'),
    );
  });
});

describe('the clerk-ios host', () => {
  it('runs the simulator locally on a Mac and remotely anywhere else', async () => {
    const { host: real } = await import('../src/host.ts');
    assert.equal(selectBackend(real, 'ios', undefined, null, 'darwin').backend.kind, 'local');
    const onLinux = selectBackend(real, 'ios', undefined, null, 'linux');
    assert.equal(onLinux.backend.kind, 'remote');
    assert.match(onLinux.why, /^local is out: the iOS simulator needs macOS and this machine runs linux; /);
  });
});

describe('backend selection', () => {
  const backend = (kind: 'local' | 'remote', usable: boolean, why: string) => ({ kind, platform: 'ios', requirement: `${kind} needs`, availability: () => ({ usable, why }) }) as unknown as DeviceBackend;
  const host = (backends: DeviceBackend[]) => ({ repo: 'clerk-ios', backends }) as unknown as HostAdapter;

  it('takes local where the machine can run the device and says why', () => {
    const choice = selectBackend(host([backend('local', true, 'this Mac runs the simulator itself'), backend('remote', true, 'a runner')]), 'ios', undefined, null);
    assert.equal(choice.backend.kind, 'local');
    assert.equal(choice.why, 'this Mac runs the simulator itself');
  });

  it('falls through to remote and names why local is out', () => {
    const choice = selectBackend(host([backend('local', false, 'the iOS simulator needs macOS and this machine runs linux'), backend('remote', true, 'a runner')]), 'ios', undefined, null);
    assert.equal(choice.backend.kind, 'remote');
    assert.equal(choice.why, 'local is out: the iOS simulator needs macOS and this machine runs linux; a runner');
  });

  it('lets --backend force either way, and keeps the backend of a held lease', () => {
    const both = host([backend('local', true, 'x'), backend('remote', true, 'y')]);
    assert.equal(selectBackend(both, 'ios', 'remote', null).backend.kind, 'remote');
    assert.equal(selectBackend(both, 'ios', undefined, { backend: 'remote' } as never).backend.kind, 'remote');
    const linux = host([backend('local', false, 'the iOS simulator needs macOS and this machine runs linux'), backend('remote', true, 'y')]);
    assert.throws(() => selectBackend(linux, 'ios', 'local', null), (error: VerifyFailure) => error.code === 'UNSUPPORTED' && error.message.includes('needs macOS'));
    assert.match(selectBackend(both, 'ios', undefined, { backend: 'remote' } as never).why, /already holds a remote lease/);
  });
});
