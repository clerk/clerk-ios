import { existsSync } from 'node:fs';
import type { Runner } from '../exec.ts';
import { sleep } from '../exec.ts';
import { Secret } from '../secret.ts';
import { VerifyFailure } from '../types.ts';
import { RUN_TITLE, triggerBranch, type SessionRequest } from './protocol.ts';
import { sessionCall, type SessionRef } from './session.ts';

/** Plain REST and plain git only: a cloud sandbox may have no `gh`, may not follow redirects to other hosts, and may not speak GraphQL. */

export type TokenSource = 'GH_TOKEN' | 'GITHUB_TOKEN' | 'gh' | 'none';

export interface ApiResponse {
  readonly status: number;
  readonly json: unknown;
  readonly headers: Headers;
  /** Set when a read was refused with the token and then tried again without it: the first refusal. */
  readonly refusedWithToken?: string;
}

export interface GitHub {
  readonly repo: string;
  readonly workflow: string;
  readonly tokenSource: TokenSource;
  api(method: 'GET' | 'POST', path: string, body?: unknown): Promise<ApiResponse>;
}

export interface GitHubOptions {
  readonly repo: string;
  readonly workflow: string;
  readonly env: Readonly<Record<string, string | undefined>>;
  readonly runner: Runner;
  /** Tests shorten the wait between retries of a read that got a 5xx. */
  readonly retryDelayMs?: number;
}

const TRANSIENT_RETRIES = 3;

export async function openGitHub(options: GitHubOptions): Promise<GitHub> {
  const { env } = options;
  let tokenSource: TokenSource = 'none';
  let token: Secret<'github-token'> | null = null;
  const fromEnv = (['GH_TOKEN', 'GITHUB_TOKEN'] as const).find((name) => (env[name] ?? '') !== '');
  if (fromEnv !== undefined) {
    tokenSource = fromEnv;
    token = new Secret('github-token', env[fromEnv]!);
  } else {
    const gh = await options.runner('gh', ['auth', 'token']);
    if (gh.code === 0 && gh.stdout.trim() !== '') {
      tokenSource = 'gh';
      token = new Secret('github-token', gh.stdout.trim());
    }
  }
  const base = (env.GITHUB_API_URL ?? 'https://api.github.com').replace(/\/$/, '');
  return {
    repo: options.repo,
    workflow: options.workflow,
    tokenSource,
    async api(method, path, body) {
      const send = async (authorized: boolean): Promise<ApiResponse> => {
        const headers: Record<string, string> = { Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'verify-remote' };
        if (body !== undefined) headers['Content-Type'] = 'application/json';
        if (authorized) token?.use('github-authorization', (plain) => (headers.Authorization = `Bearer ${plain}`));
        const response = await fetch(`${base}/repos/${options.repo}${path}`, { method, headers, body: body === undefined ? undefined : JSON.stringify(body), redirect: 'manual', signal: AbortSignal.timeout(30_000) });
        const text = await response.text();
        let json: unknown = null;
        try {
          json = text === '' ? null : JSON.parse(text);
        } catch {
          json = null;
        }
        return { status: response.status, json, headers: response.headers };
      };
      let first = await send(true);
      // GitHub answers a read with a 5xx now and then. A failed read here can fail an `up` that was about to end a billed run.
      for (let attempt = 1; method === 'GET' && first.status >= 500 && attempt <= TRANSIENT_RETRIES; attempt += 1) {
        await sleep(attempt * (options.retryDelayMs ?? 1500));
        first = await send(true);
      }
      // A token that GitHub rejects must not hide a public repository: reads fall back to no token.
      if (method !== 'GET' || token === null || (first.status !== 401 && first.status !== 403)) return first;
      return { ...(await send(false)), refusedWithToken: message(first) };
    },
  };
}

/** The one cause of a refused write that the refusal itself does not explain to someone outside the sandbox. */
export const CLOUD_GITHUB_ACCESS =
  'In a Claude Code cloud session, a 403 on git push means the Claude GitHub App is not installed on this repository for the organization: an org admin adds the repository to the app, or the user reconnects GitHub in claude.ai settings. REST calls there use the session user\'s own access and do not depend on the app';

/** What git said went wrong: the server's own `remote:` lines, which carry the reason, then git's last line. */
export function gitFailure(output: string): string {
  const lines = output.trim().split('\n').map((line) => line.trim()).filter((line) => line !== '');
  const remote = lines.filter((line) => line.startsWith('remote:')).map((line) => line.replace(/^remote:\s*/, ''));
  return [...remote, lines.at(-1) ?? 'no output'].filter((line, i, all) => all.indexOf(line) === i).join(' | ');
}

const message = (response: ApiResponse): string => `${response.status}${typeof (response.json as { message?: unknown } | null)?.message === 'string' ? ` ${(response.json as { message: string }).message}` : ''}`;

export interface StartedRun {
  readonly runId: string;
  readonly trigger: 'dispatch' | 'push';
  /** Why dispatch was not used, when the push trigger was. */
  readonly dispatchRefused: string | null;
}

export interface StartOptions {
  /** The branch whose workflow file a dispatch runs. */
  readonly ref: string;
  readonly worktree: string;
  readonly runner: Runner;
  /** How long to wait for a dispatched run to be readable. Tests shorten it. */
  readonly readableWithinMs?: number;
}

/**
 * A dispatch returns its run id before a read of that run answers 200: for a moment the read is a 404. Callers poll the
 * run right away and treat a failed read as the run being gone, so the id is handed out only once it reads.
 */
async function untilReadable(github: GitHub, runId: string, withinMs: number): Promise<void> {
  const deadline = Date.now() + withinMs;
  while ((await github.api('GET', `/actions/runs/${runId}`)).status !== 200 && Date.now() < deadline) await sleep(Math.min(1500, withinMs / 4));
}

async function findRun(github: GitHub, query: string, matches: (run: { id: number; display_title: string }) => boolean, seconds: number): Promise<string | null> {
  const deadline = Date.now() + seconds * 1000;
  for (;;) {
    const listed = await github.api('GET', `/actions/workflows/${github.workflow}/runs?per_page=20&${query}`);
    const runs = ((listed.json as { workflow_runs?: { id: number; display_title: string }[] } | null)?.workflow_runs ?? []).filter(matches);
    if (runs[0] !== undefined) return String(runs[0].id);
    if (Date.now() >= deadline) return null;
    await sleep(3000);
  }
}

const isRunOf = (request: Pick<SessionRequest, 'owner' | 'session'>) => (run: { display_title: string }): boolean => {
  const title = RUN_TITLE.exec(run.display_title);
  return title !== null && title[1] === request.owner && title[2] === request.session;
};

/** Tries workflow_dispatch, then the push trigger, so a driver that may not dispatch still gets a session. */
export async function startRun(github: GitHub, request: SessionRequest, options: StartOptions): Promise<StartedRun> {
  const dispatched = await github.api('POST', `/actions/workflows/${github.workflow}/dispatches`, {
    ref: options.ref,
    inputs: { owner: request.owner, session: request.session, request: JSON.stringify(request) },
    return_run_details: true,
  });
  if (dispatched.status === 200 || dispatched.status === 204) {
    const direct = (dispatched.json as { workflow_run_id?: number } | null)?.workflow_run_id;
    const runId = direct !== undefined ? String(direct) : await findRun(github, 'event=workflow_dispatch', isRunOf(request), 180);
    if (runId === null) throw new VerifyFailure('NOT_READY', `GitHub accepted the dispatch of ${github.workflow} but no run for session ${request.session} appeared in 3 minutes; if it starts later it bills until it idles out`, `{cli} down --stale ends it once it shows at https://github.com/${github.repo}/actions/workflows/${github.workflow}`);
    await untilReadable(github, runId, options.readableWithinMs ?? 60_000);
    return { runId, trigger: 'dispatch', dispatchRefused: null };
  }
  const dispatchRefused = message(dispatched);

  const git = (args: readonly string[]) => options.runner('git', args, { cwd: options.worktree });
  const tree = await git(['rev-parse', 'HEAD^{tree}']);
  const commit = await git(['-c', 'user.name=verify-remote', '-c', 'user.email=verify-remote@users.noreply.github.com', 'commit-tree', tree.stdout.trim(), '-p', 'HEAD', '-m', JSON.stringify(request)]);
  const branch = triggerBranch(request);
  const pushed = commit.code === 0 ? await git(['push', '--quiet', 'origin', `${commit.stdout.trim()}:refs/heads/${branch}`]) : commit;
  const leftover = `; the branch ${branch} was pushed and is left on the remote, delete it with git push origin :${branch}`;
  if (pushed.code !== 0) {
    throw new VerifyFailure(
      'NOT_READY',
      `could not start a session: workflow_dispatch was refused (${dispatchRefused}) and pushing ${branch} failed: ${gitFailure(pushed.stderr || pushed.stdout)}`,
      `a session needs one of two things: permission to dispatch ${github.workflow} on ${github.repo}, or permission to push a branch named verify-remote/*; push the branch that holds ${github.workflow} first if GitHub has never seen it. ${CLOUD_GITHUB_ACCESS}`,
    );
  }
  const runId = await findRun(github, `event=push&branch=${encodeURIComponent(branch)}`, () => true, 180);
  if (runId === null) throw new VerifyFailure('NOT_READY', `pushed ${branch} but no ${github.workflow} run started`, `check that the pushed commit holds .github/workflows/${github.workflow}${leftover}`);
  return { runId, trigger: 'push', dispatchRefused };
}

export interface RunView {
  readonly status: string;
  readonly conclusion: string | null;
  readonly url: string;
}

export async function viewRun(github: GitHub, runId: string): Promise<RunView> {
  const response = await github.api('GET', `/actions/runs/${runId}`);
  if (response.status !== 200) throw new VerifyFailure('NOT_READY', `could not read run ${runId}: ${message(response)}`, `open https://github.com/${github.repo}/actions/runs/${runId}`);
  const run = response.json as { status: string; conclusion: string | null; html_url: string };
  return { status: run.status, conclusion: run.conclusion, url: run.html_url };
}

export interface JobView {
  readonly name: string;
  readonly status: string;
  readonly conclusion: string | null;
  readonly steps: readonly { readonly name: string; readonly status: string; readonly conclusion: string | null }[];
}

export async function viewJobs(github: GitHub, runId: string): Promise<readonly JobView[]> {
  const response = await github.api('GET', `/actions/runs/${runId}/jobs?per_page=30`);
  if (response.status !== 200) return [];
  type Wire = { name: string; status: string; conclusion: string | null; steps?: { name: string; status: string; conclusion: string | null }[] };
  return ((response.json as { jobs?: Wire[] } | null)?.jobs ?? []).map((job) => ({
    name: job.name,
    status: job.status,
    conclusion: job.conclusion,
    steps: (job.steps ?? []).map((step) => ({ name: step.name, status: step.status, conclusion: step.conclusion })),
  }));
}

/** The value a session run published in a step name, or null while that step has not started. */
export function publishedStep(jobs: readonly JobView[], pattern: RegExp): string | null {
  for (const job of jobs) {
    for (const step of job.steps) {
      const found = pattern.exec(step.name)?.[1];
      if (found !== undefined && found !== '') return found;
    }
  }
  return null;
}

export async function waitForStep(github: GitHub, runId: string, pattern: RegExp, seconds: number, onWait?: (run: RunView, jobs: readonly JobView[]) => void): Promise<string> {
  const deadline = Date.now() + seconds * 1000;
  for (;;) {
    const jobs = await viewJobs(github, runId);
    const found = publishedStep(jobs, pattern);
    if (found !== null) return found;
    const run = await viewRun(github, runId);
    if (run.status === 'completed') {
      const failed = jobs.flatMap((job) => job.steps.filter((step) => step.conclusion === 'failure').map((step) => `${job.name}: ${step.name}`));
      throw new VerifyFailure('NOT_READY', `run ${runId} ended (${run.conclusion ?? 'no conclusion'}) before it published${failed.length > 0 ? `; failed at ${failed.join(', ')}` : ''}`, `read ${run.url}`);
    }
    if (Date.now() >= deadline) throw new VerifyFailure('NOT_READY', `run ${runId} published nothing within ${seconds}s (it is ${run.status})`, `read ${run.url}; a runner label with no free machine stays queued`);
    onWait?.(run, jobs);
    await sleep(4000);
  }
}

export async function waitForRunEnd(github: GitHub, runId: string, seconds: number): Promise<RunView> {
  const deadline = Date.now() + seconds * 1000;
  for (;;) {
    const run = await viewRun(github, runId);
    if (run.status === 'completed' || Date.now() >= deadline) return run;
    await sleep(4000);
  }
}

export async function cancelRun(github: GitHub, runId: string): Promise<string | null> {
  const response = await github.api('POST', `/actions/runs/${runId}/cancel`);
  return response.status === 202 || response.status === 409 ? null : message(response);
}

export interface LiveRun {
  readonly runId: string;
  readonly owner: string;
  readonly session: string;
  readonly createdAt: string;
}

/** Session runs GitHub still counts as queued or running, with the driver each belongs to. */
export async function liveRuns(github: GitHub): Promise<readonly LiveRun[]> {
  const out: LiveRun[] = [];
  for (const status of ['in_progress', 'queued'] as const) {
    const listed = await github.api('GET', `/actions/workflows/${github.workflow}/runs?per_page=50&status=${status}`);
    for (const run of (listed.json as { workflow_runs?: { id: number; display_title: string; created_at: string }[] } | null)?.workflow_runs ?? []) {
      const title = RUN_TITLE.exec(run.display_title);
      if (title !== null) out.push({ runId: String(run.id), owner: title[1]!, session: title[2]!, createdAt: run.created_at });
    }
  }
  return out;
}

export async function currentBranch(runner: Runner, worktree: string): Promise<string> {
  const branch = (await runner('git', ['rev-parse', '--abbrev-ref', 'HEAD'], { cwd: worktree })).stdout.trim();
  if (branch === '' || branch === 'HEAD') throw new VerifyFailure('NOT_READY', 'HEAD is detached, so there is no branch to start a session from', 'git switch -c <branch>, then git push -u origin <branch>');
  return branch;
}

/** `ref` is null for a session this driver cannot reach, which can only be cancelled. */
export async function endSession(github: GitHub, runId: string, ref: SessionRef | null): Promise<{ readonly conclusion: string | null; readonly cancelled: boolean; readonly problem: string | null }> {
  if (ref !== null && existsSync(ref.tokenFile)) await sessionCall(ref, '/__sim/stop', { method: 'POST', timeoutMs: 15_000 }).catch(() => undefined);
  let run = await waitForRunEnd(github, runId, ref === null ? 0 : 90);
  if (run.status === 'completed') return { conclusion: run.conclusion, cancelled: false, problem: null };
  const refused = await cancelRun(github, runId);
  run = await waitForRunEnd(github, runId, 60);
  if (run.status === 'completed') return { conclusion: run.conclusion, cancelled: true, problem: null };
  return { conclusion: null, cancelled: refused === null, problem: `run ${runId} is still ${run.status}${refused === null ? '' : ` and the cancel was refused (${refused})`}; it ends itself on idle or at its cap` };
}

export { message as apiMessage };
