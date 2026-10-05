import net from 'node:net';
import { arch, platform as osPlatform, release } from 'node:os';
import type { Runner } from '../exec.ts';
import { VerifyFailure, type DoctorCheck, type DoctorCheckId, type DoctorOptions } from '../types.ts';
import { CLOUD_GITHUB_ACCESS, apiMessage, currentBranch, endSession, gitFailure, liveRuns, startRun, viewJobs, waitForStep, type ApiResponse, type GitHub, type StartedRun } from './github.ts';
import { STEP, probeEcho, triggerBranch } from './protocol.ts';
import { daemonHealthy, firstHealth, sessionHealth, tunnelUrl, type SessionRef } from './session.ts';
import { driverId, forgetSession, newSessionRequest, saveToken, type RemoteDeps, type RemoteSettings } from './settings.ts';
import { TUNNEL } from './tunnel.ts';

const CLOUD_FIX = `add ${TUNNEL.allowedHost} to the allowed domains of the cloud environment the session runs in (Claude Code: the Default environment's network settings)`;

function check(id: DoctorCheckId, ok: boolean, detail: string, fix: string): DoctorCheck {
  return ok ? { id, ok, detail } : { id, ok, detail, fix };
}

/** A check that depends on a failed one still prints, so a reader never has to infer what was not tested. */
const notRun = (id: DoctorCheckId, needs: DoctorCheckId, why = ''): DoctorCheck => check(id, false, `not run: needs ${needs}${why === '' ? '' : ` (${why})`}`, `fix ${needs} first`);

const failureText = (error: unknown): string => {
  const cause = (error as { cause?: { code?: string; message?: string } }).cause;
  return `${(error as Error).message}${cause === undefined ? '' : ` (${cause.code ?? cause.message ?? ''})`}`;
};

function proxyOf(env: RemoteDeps['env']): URL | null {
  const raw = env.HTTPS_PROXY ?? env.https_proxy;
  if (raw === undefined || raw === '') return null;
  try {
    return new URL(raw);
  } catch {
    return null;
  }
}

/** Asks the proxy for a CONNECT and returns its status line, which is where a sandbox says no. */
export function connectThroughProxy(proxy: URL, host: string, timeoutMs = 10_000): Promise<{ readonly status: number; readonly line: string }> {
  return new Promise((resolve) => {
    const socket = net.connect(Number(proxy.port || 80), proxy.hostname);
    let seen = '';
    const finish = (status: number, line: string) => {
      socket.destroy();
      resolve({ status, line });
    };
    socket.setTimeout(timeoutMs, () => finish(0, 'the proxy did not answer'));
    socket.on('error', (error) => finish(0, `the proxy is unreachable: ${error.message}`));
    socket.on('connect', () => socket.write(`CONNECT ${host}:443 HTTP/1.1\r\nHost: ${host}:443\r\n\r\n`));
    socket.on('data', (chunk: Buffer) => {
      seen += chunk.toString('latin1');
      const end = seen.indexOf('\r\n');
      if (end < 0) return;
      const line = seen.slice(0, end);
      finish(Number(/^HTTP\/\d\.\d (\d{3})/.exec(line)?.[1] ?? 0), line);
    });
  });
}

/**
 * For a host that Cloudflare serves. Only an answer that carries Cloudflare's own headers counts as reached: a
 * sandbox that inspects TLS can answer for the host itself, and its refusal page is an HTTP response too.
 */
export async function egressCheck(id: DoctorCheckId, host: string, env: RemoteDeps['env'], fix: string, request: typeof fetch = fetch): Promise<DoctorCheck> {
  const proxy = proxyOf(env);
  const usesProxy = proxy !== null && env.NODE_USE_ENV_PROXY === '1';
  if (usesProxy) {
    const connect = await connectThroughProxy(proxy, host);
    if (connect.status !== 200) return check(id, false, `blocked: the proxy at ${proxy.host} answered the CONNECT to ${host} with "${connect.line}"`, fix);
  }
  const via = usesProxy ? ` through the proxy at ${proxy.host}` : '';
  try {
    const response = await request(`https://${host}/`, { redirect: 'manual', signal: AbortSignal.timeout(15_000) });
    const fromCloudflare = response.headers.has('cf-ray') || response.headers.get('server') === 'cloudflare';
    if (fromCloudflare) return check(id, true, `reached ${host}${via}: HTTP ${response.status} from cloudflare`, '');
    return check(id, false, `blocked: ${host} answered HTTP ${response.status}${via} without Cloudflare's headers, so something between this machine and the host answered in its place`, fix);
  } catch (error) {
    return check(id, false, `no response from ${host}${via}: ${failureText(error)}`, fix);
  }
}

async function environmentCheck(github: GitHub, deps: RemoteDeps, worktree: string): Promise<DoctorCheck> {
  const npm = await deps.runner('npm', ['--version']);
  const gh = await deps.runner('gh', ['--version']);
  const remote = (await deps.runner('git', ['remote', 'get-url', 'origin'], { cwd: worktree })).stdout.trim();
  const remoteKind = /^(git@|ssh:)/.test(remote) ? 'ssh' : /^https?:\/\/(127\.0\.0\.1|localhost)/.test(remote) ? 'a local git proxy' : /^https?:/.test(remote) ? 'https' : 'unknown';
  const proxy = proxyOf(deps.env);
  const why = deps.env.VERIFY_EGRESS_WHY === undefined ? '' : ` (${deps.env.VERIFY_EGRESS_WHY})`;
  const egress = proxy === null ? 'direct (no HTTPS_PROXY)' : deps.env.NODE_USE_ENV_PROXY === '1' ? `through the proxy at ${proxy.host}${why}` : `direct, not through the proxy at ${proxy.host}${why}`;
  const detail = [
    `${osPlatform()} ${arch()} ${release()}`,
    `npm ${npm.code === 0 ? npm.stdout.trim() : 'missing'}`,
    `gh ${gh.code === 0 ? 'present' : 'absent'}`,
    `GitHub token from ${github.tokenSource === 'none' ? 'nowhere' : github.tokenSource}`,
    `origin over ${remoteKind}`,
    `egress ${egress}`,
  ].join('; ');
  return check('remote-env', npm.code === 0, detail, 'install npm with Node 24');
}

type Git = (args: readonly string[]) => Promise<{ readonly code: number; readonly stdout: string; readonly stderr: string }>;

/**
 * Where HEAD stands against the branch on the remote. A clone that a cloud service reuses can sit on a commit the
 * branch has since moved past, or rewritten away, and then every later check tests old code.
 */
async function headCheck(git: Git, branch: string): Promise<DoctorCheck> {
  const head = (await git(['rev-parse', 'HEAD'])).stdout.trim();
  const tip = (await git(['ls-remote', 'origin', `refs/heads/${branch}`])).stdout.split(/\s/)[0] ?? '';
  const resync = `git fetch origin ${branch} && git reset --hard FETCH_HEAD (this drops local commits and edits; keep them with git rebase FETCH_HEAD instead)`;
  if (tip === '') return check('git-head', true, `origin has no branch ${branch} yet`, '');
  if (tip === head) return check('git-head', true, `HEAD ${head.slice(0, 12)} is the tip of origin/${branch}`, '');
  const have = (await git(['cat-file', '-e', `${tip}^{commit}`])).code === 0;
  const ahead = have && (await git(['merge-base', '--is-ancestor', tip, 'HEAD'])).code === 0;
  if (ahead) return check('git-head', true, `HEAD ${head.slice(0, 12)} is ahead of origin/${branch} at ${tip.slice(0, 12)}`, '');
  const behind = have && (await git(['merge-base', '--is-ancestor', 'HEAD', tip])).code === 0;
  return check(
    'git-head',
    false,
    behind
      ? `HEAD ${head.slice(0, 12)} is behind origin/${branch}, which is at ${tip.slice(0, 12)}; this is an old checkout`
      : `HEAD ${head.slice(0, 12)} is not on origin/${branch}, which is at ${tip.slice(0, 12)}${have ? '' : ' (a commit this clone has not fetched)'}; the checkout is stale or the branch was rewritten`,
    resync,
  );
}

async function gitChecks(settings: RemoteSettings, runner: Runner, worktree: string): Promise<readonly DoctorCheck[]> {
  const git = (args: readonly string[]) => runner('git', args, { cwd: worktree, env: { ...process.env, GIT_TERMINAL_PROMPT: '0' } });
  let branch: string;
  try {
    branch = await currentBranch(runner, worktree);
  } catch (error) {
    const failure = error as VerifyFailure;
    return [check('git-fetch', false, failure.message, failure.fix), notRun('git-head', 'git-fetch'), notRun('git-push', 'git-fetch')];
  }
  const fetched = await git(['fetch', '--dry-run', '--no-tags', 'origin', branch]);
  const pushOwn = await git(['push', '--dry-run', 'origin', `HEAD:refs/heads/${branch}`]);
  const trigger = triggerBranch({ owner: driverId(settings), session: 'doctor' });
  const pushTrigger = await git(['push', '--dry-run', 'origin', `HEAD:refs/heads/${trigger}`]);
  return [
    check('git-fetch', fetched.code === 0, fetched.code === 0 ? `git fetch origin ${branch} works` : `git fetch origin ${branch} failed: ${gitFailure(fetched.stderr)}`, `git push -u origin ${branch}, and check the remote with git remote -v`),
    fetched.code === 0 ? await headCheck(git, branch) : notRun('git-head', 'git-fetch'),
    check(
      'git-push',
      pushOwn.code === 0,
      pushOwn.code === 0
        ? `dry-run push of ${branch} is accepted; dry-run push of the trigger branch ${trigger} is ${pushTrigger.code === 0 ? 'accepted' : `refused (${gitFailure(pushTrigger.stderr)})`}`
        : `dry-run push of ${branch} failed: ${gitFailure(pushOwn.stderr)}`,
      `verifying a commit you make here needs git push access to ${settings.repo}, because a remote session builds a pushed commit; verifying a commit GitHub already has needs only REST. ${CLOUD_GITHUB_ACCESS}`,
    ),
  ];
}

const withAndWithoutToken = (response: ApiResponse): string => `${apiMessage(response)}${response.refusedWithToken === undefined ? '' : ` without the token (with it: ${response.refusedWithToken})`}`;

async function restCheck(settings: RemoteSettings, github: GitHub): Promise<DoctorCheck> {
  const fix = `check network access to api.github.com. ${CLOUD_GITHUB_ACCESS}`;
  try {
    const repo = await github.api('GET', '');
    const runs = await github.api('GET', '/actions/runs?per_page=1');
    const ok = repo.status === 200 && runs.status === 200;
    const left = repo.headers.get('x-ratelimit-remaining');
    const tokenRefused = repo.refusedWithToken !== undefined || runs.refusedWithToken !== undefined;
    return check(
      'github-rest',
      ok,
      `repository ${withAndWithoutToken(repo)}, workflow runs ${withAndWithoutToken(runs)}${left === null ? '' : `, ${left} requests left this hour`}${ok && tokenRefused ? `; reads of ${settings.repo} work, but GitHub refuses this machine's token, so starting a session will fail` : ''}`,
      fix,
    );
  } catch (error) {
    return check('github-rest', false, `api.github.com did not answer: ${failureText(error)}`, fix);
  }
}

async function commitCheck(github: GitHub, runner: Runner, worktree: string): Promise<DoctorCheck> {
  const sha = (await runner('git', ['rev-parse', 'HEAD'], { cwd: worktree })).stdout.trim();
  const found = await github.api('GET', `/commits/${sha}`).catch(() => null);
  return check('remote-commit', found?.status === 200, found?.status === 200 ? `GitHub has HEAD ${sha.slice(0, 12)}` : `GitHub does not have HEAD ${sha.slice(0, 12)} (${found === null ? 'no answer' : found.status})`, 'git push; a remote session builds the pushed commit');
}

async function probeChecks(settings: RemoteSettings, deps: RemoteDeps, github: GitHub, options: DoctorOptions): Promise<{ readonly runId: string | null; readonly checks: readonly DoctorCheck[] }> {
  const { request } = newSessionRequest(settings, deps, { mode: 'probe', runner: settings.plumbingRunner, device: null, sha: null });
  let started: StartedRun;
  try {
    started = await startRun(github, request, { ref: await currentBranch(deps.runner, options.worktree), worktree: options.worktree, runner: deps.runner });
  } catch (error) {
    const failure = error instanceof VerifyFailure ? error : new VerifyFailure('NOT_READY', failureText(error), `check access to ${settings.repo}. ${CLOUD_GITHUB_ACCESS}`);
    return { runId: null, checks: [check('remote-trigger', false, failure.message, failure.fix), notRun('remote-channel', 'remote-trigger', 'no run was started')] };
  }
  const { runId } = started;
  const trigger = check(
    'remote-trigger',
    true,
    started.trigger === 'dispatch'
      ? `workflow_dispatch started probe run ${runId} (it uses only the free plan job)`
      : `a push to ${triggerBranch(request)} started probe run ${runId}; workflow_dispatch was refused (${started.dispatchRefused})`,
    '',
  );
  const began = Date.now();
  try {
    const echo = await waitForStep(github, runId, STEP.probePattern, 180);
    const ok = echo === probeEcho(request);
    return { runId, checks: [trigger, check('remote-channel', ok, ok ? `read this probe's echo from a job step name over REST in ${Math.round((Date.now() - began) / 1000)}s` : `the probe run echoed ${echo}, not this probe's value`, 'report this as a verify bug')] };
  } catch (error) {
    return { runId, checks: [trigger, check('remote-channel', false, failureText(error), `read https://github.com/${settings.repo}/actions/runs/${runId}`)] };
  }
}

const LIVE_CHECKS = ['live-session', 'live-bearer', 'live-sim-health', 'live-daemon-health', 'live-stop'] as const satisfies readonly DoctorCheckId[];

async function liveChecks(settings: RemoteSettings, deps: RemoteDeps, github: GitHub, options: DoctorOptions): Promise<readonly DoctorCheck[]> {
  const withDevice = options.runner !== undefined;
  const { request, token } = newSessionRequest(settings, deps, {
    mode: 'session',
    runner: options.runner ?? settings.plumbingRunner,
    device: withDevice ? settings.device : null,
    sha: null,
    idleMinutes: 3,
    capMinutes: withDevice ? 20 : 10,
  });
  const tokenFile = saveToken(settings, request.session, token);
  const checks: DoctorCheck[] = [];
  const began = Date.now();
  const seconds = () => Math.round((Date.now() - began) / 1000);
  const runUrl = (runId: string) => `https://github.com/${settings.repo}/actions/runs/${runId}`;
  let runId: string | null = null;
  let session: SessionRef | null = null;
  try {
    const started = await startRun(github, request, { ref: await currentBranch(deps.runner, options.worktree), worktree: options.worktree, runner: deps.runner });
    runId = started.runId;
    options.progress(`live    session ${request.session} is run ${runId} on ${request.runner}, started by ${started.trigger}; it stops itself after 3 idle minutes`);
    const host = await waitForStep(github, runId, STEP.tunnelPattern, 15 * 60);
    session = { baseUrl: tunnelUrl(host), tokenFile };
    checks.push(check('live-session', true, `run ${runId} on ${request.runner} published its tunnel ${seconds()}s after the ${started.trigger}`, ''));

    const health = await firstHealth(session, 120);
    checks.push(check('live-sim-health', health !== null, health === null ? '/__sim/health did not answer 200 with the bearer' : `/__sim/health answered through the tunnel ${seconds()}s in`, CLOUD_FIX));

    const bare = await fetch(`${session.baseUrl}/__sim/health`, { signal: AbortSignal.timeout(15_000) }).then(async (r) => `${r.status} ${await r.text()}`).catch((error: unknown) => failureText(error));
    checks.push(check('live-bearer', bare.startsWith('403') && bare.includes('session token required'), `without the bearer the tunnel answers ${bare.slice(0, 80)}`, CLOUD_FIX));

    let daemon = false;
    let deviceReady = !withDevice;
    const deadline = Date.now() + (withDevice ? 12 : 4) * 60_000;
    while (health !== null && Date.now() < deadline && !(daemon && deviceReady)) {
      daemon = daemon || (await daemonHealthy(session));
      deviceReady = deviceReady || (await sessionHealth(session))?.device?.ready === true;
      if (!(daemon && deviceReady)) await new Promise((done) => setTimeout(done, 5000));
    }
    checks.push(check('live-daemon-health', daemon, daemon ? `/agent-device/health answered through the tunnel ${seconds()}s in` : '/agent-device/health never answered ok', `read ${runUrl(runId)}`));
    if (withDevice) checks.push(check('live-device', deviceReady, deviceReady ? `${settings.device} was ready on ${request.runner} ${seconds()}s in` : `${settings.device} was not ready in time`, `read ${runUrl(runId)}; --runner needs a runner image that has a device named ${settings.device}`));
  } catch (error) {
    const failure = error instanceof VerifyFailure ? error : new VerifyFailure('NOT_READY', failureText(error), 'run doctor again');
    const failed = LIVE_CHECKS.find((id) => !checks.some((c) => c.id === id)) ?? 'live-session';
    checks.push(check(failed, false, failure.message, failure.fix));
  } finally {
    if (runId !== null) {
      const stopAt = Date.now();
      const ended = await endSession(github, runId, session);
      const sessionJob = (await viewJobs(github, runId)).find((job) => job.name === 'session');
      checks.push(
        check(
          'live-stop',
          ended.problem === null && !ended.cancelled,
          ended.problem ?? `${ended.cancelled ? 'the stop route did not end the run, so it was cancelled' : 'the stop route ended the run'}: run ${ended.conclusion}, session job ${sessionJob?.status ?? 'not started'} ${Math.round((Date.now() - stopAt) / 1000)}s after the stop`,
          `open ${runUrl(runId)} and cancel it`,
        ),
      );
    }
    forgetSession(settings, request.session);
  }
  const reached = new Set(checks.map((c) => c.id));
  const firstFailure = checks.find((c) => !c.ok)?.id ?? 'live-session';
  return [...checks, ...LIVE_CHECKS.filter((id) => !reached.has(id)).map((id) => notRun(id, firstFailure))];
}

export async function remoteDoctorChecks(settings: RemoteSettings, deps: RemoteDeps, openHub: () => Promise<GitHub>, options: DoctorOptions): Promise<{ readonly toolchain: readonly DoctorCheck[]; readonly device: readonly DoctorCheck[] }> {
  const github = await openHub();
  const toolchain = [await environmentCheck(github, deps, options.worktree)];
  const device: DoctorCheck[] = [...(await gitChecks(settings, deps.runner, options.worktree))];
  const rest = await restCheck(settings, github);
  device.push(rest);
  let canStart: DoctorCheckId | null = null;
  let probeRunId: string | null = null;
  if (!rest.ok) {
    canStart = 'github-rest';
    device.push(notRun('remote-commit', 'github-rest'), notRun('remote-trigger', 'github-rest'), notRun('remote-channel', 'github-rest'));
  } else {
    const commit = await commitCheck(github, deps.runner, options.worktree);
    device.push(commit);
    if (!commit.ok) {
      // The push trigger would publish this HEAD, which doctor has just found is not on GitHub.
      canStart = 'remote-commit';
      device.push(notRun('remote-trigger', 'remote-commit', 'the probe must not push a commit you have not pushed'), notRun('remote-channel', 'remote-commit'));
    } else {
      const probe = await probeChecks(settings, deps, github, options);
      probeRunId = probe.runId;
      device.push(...probe.checks);
      if (probe.checks.some((c) => !c.ok)) canStart = probe.checks.find((c) => !c.ok)!.id;
    }
  }
  device.push(await egressCheck('tunnel-egress', TUNNEL.probeHost, deps.env, CLOUD_FIX));
  device.push(await egressCheck('clerk-egress', 'api.clerk.com', deps.env, 'add api.clerk.com and *.clerk.accounts.dev to the allowed domains; the driver creates test users and sign-in tickets there'));
  if (rest.ok) {
    const mine = (await liveRuns(github)).filter((run) => run.owner === driverId(settings) && run.runId !== probeRunId);
    device.push(check('remote-sessions', true, mine.length === 0 ? 'no session of this checkout is running' : `running for this checkout and billed until ended: ${mine.map((run) => `${run.session} (run ${run.runId})`).join(', ')}; {cli} down ends a leased session and {cli} down --stale ends any other`, ''));
  }
  if (options.live) device.push(...(canStart === null ? await liveChecks(settings, deps, github, options) : LIVE_CHECKS.map((id) => notRun(id, canStart))));
  return { toolchain, device };
}
