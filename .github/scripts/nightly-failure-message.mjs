import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

const LISTED = 20;
const RUNS_PER_WORKFLOW = 100;
const COMMIT_PAGES = 10;
const PARALLEL = 8;

function client({ fetch, api, token, repo }) {
  return async (path, { missing } = {}) => {
    const response = await fetch(`${api}/repos/${repo}${path}`, {
      headers: { accept: 'application/vnd.github+json', authorization: `Bearer ${token}`, 'x-github-api-version': '2022-11-28' },
    });
    if (missing !== undefined && response.status === 404) {
      return missing;
    }
    if (!response.ok) {
      throw new Error(`GET ${path} answered ${response.status}: ${(await response.text()).slice(0, 300)}`);
    }
    return response.json();
  };
}

const startedAt = run => run.run_started_at ?? run.created_at;

const ranFullSuiteOnMain = run => run.event === 'schedule' || run.event === 'release' || (run.event === 'workflow_dispatch' && run.head_branch === 'main');

// A release run passes whether or not it ran these checks, so a `file=job` source counts a run only when that job passed.
function source(arg) {
  const at = arg.indexOf('=');
  return at === -1 ? { file: arg, job: null } : { file: arg.slice(0, at), job: arg.slice(at + 1) };
}

async function passedJob(get, run, name) {
  const { jobs } = await get(`/actions/runs/${run.id}/jobs?per_page=100`);
  return jobs.some(job => job.name === name && job.conclusion === 'success');
}

async function lastPassingRun(get, { sha, runId, sources }) {
  const listed = await Promise.all(
    sources.map(async ({ file, job }) => {
      const page = await get(`/actions/workflows/${encodeURIComponent(file)}/runs?status=success&exclude_pull_requests=true&per_page=${RUNS_PER_WORKFLOW}`);
      return page.workflow_runs.map(run => ({ run, job }));
    }),
  );
  const runs = listed
    .flat()
    .filter(({ run }) => ranFullSuiteOnMain(run) && String(run.id) !== String(runId))
    .sort((a, b) => startedAt(b.run).localeCompare(startedAt(a.run)));
  const ancestor = new Map();
  for (const { run, job } of runs) {
    if (!ancestor.has(run.head_sha)) {
      const compared = await get(`/compare/${run.head_sha}...${sha}?per_page=1`, { missing: { status: 'unrelated' } });
      ancestor.set(run.head_sha, compared.status === 'ahead' || compared.status === 'identical');
    }
    if (ancestor.get(run.head_sha) && (job === null || (await passedJob(get, run, job)))) {
      return run;
    }
  }
  return null;
}

async function commitsBetween(get, base, head) {
  const commits = [];
  for (let page = 1; page <= COMMIT_PAGES; page += 1) {
    const compared = await get(`/compare/${base}...${head}?per_page=100&page=${page}`);
    commits.push(...compared.commits);
    if (compared.commits.length === 0 || commits.length >= compared.total_commits) {
      break;
    }
  }
  return commits.map(commit => commit.sha).reverse();
}

async function mergedPullRequests(get, shas) {
  const found = [];
  for (let at = 0; at < shas.length; at += PARALLEL) {
    const batch = shas.slice(at, at + PARALLEL);
    const pulls = await Promise.all(batch.map(sha => get(`/commits/${sha}/pulls`)));
    batch.forEach((sha, index) => {
      const merged = pulls[index].filter(pull => pull.merged_at);
      const pull = merged.find(candidate => candidate.merge_commit_sha === sha) ?? merged[0];
      if (pull !== undefined && !found.some(seen => seen.number === pull.number)) {
        found.push(pull);
      }
    });
  }
  return found;
}

const mrkdwn = text => text.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');

const minute = iso => `${iso.slice(0, 10)} ${iso.slice(11, 16)}`;

function sinceLastPass(passing, pulls) {
  if (passing === null) {
    return 'No earlier passing run was found, so no pull requests are listed.';
  }
  const since = `the <${passing.html_url}|last passing run> (${minute(startedAt(passing))} UTC)`;
  if (pulls.length === 0) {
    return `No pull requests were merged since ${since}.`;
  }
  const lines = pulls.slice(0, LISTED).map(pull => `• <${pull.html_url}|#${pull.number} ${mrkdwn(pull.title)}> · ${pull.user.login}`);
  if (pulls.length > LISTED) {
    lines.push(`and ${pulls.length - LISTED} more`);
  }
  return [`Merged since ${since}:`, ...lines].join('\n');
}

async function nightlyFailureMessage({ fetch, api, token, repo, sha, runId, sources }) {
  const get = client({ fetch, api, token, repo });
  const passing = await lastPassingRun(get, { sha, runId, sources });
  if (passing === null) {
    return sinceLastPass(null, []);
  }
  const shas = await commitsBetween(get, passing.head_sha, sha);
  return sinceLastPass(passing, await mergedPullRequests(get, shas));
}

const listed = labels => (labels.length < 3 ? labels.join(' and ') : `${labels.slice(0, -1).join(', ')}, and ${labels.at(-1)}`);

function blockedRelease(gates, needs, release) {
  const ended = result => gates.filter(({ job }) => needs[job]?.result === result).map(({ label }) => label);
  const reasons = [
    [ended('failure'), 'failed'],
    [ended('cancelled'), 'got cancelled or timed out'],
  ]
    .filter(([labels]) => labels.length > 0)
    .map(([labels, verb]) => `${listed(labels)} ${verb}`);
  if (reasons.length === 0) {
    throw new Error(`no gate failed or was cancelled: ${JSON.stringify(needs)}`);
  }
  return `${release ? `${mrkdwn(release)} ` : ''}release blocked: ${reasons.join('; ')}`;
}

async function main(args, env, { fetch = globalThis.fetch, out = process.stdout } = {}) {
  if (args[0] === '--release') {
    const gates = args.slice(1).map(arg => ({ job: arg.slice(0, arg.indexOf('=')), label: arg.slice(arg.indexOf('=') + 1) }));
    out.write(`${blockedRelease(gates, JSON.parse(env.NEEDS ?? '{}'), env.RELEASE ?? '')}\n`);
    return;
  }
  const missing = ['GITHUB_REPOSITORY', 'GITHUB_SHA', 'GITHUB_RUN_ID', 'GITHUB_TOKEN'].filter(name => !env[name]);
  if (args.length === 0 || missing.length > 0) {
    throw new Error(`usage: GITHUB_REPOSITORY, GITHUB_SHA, GITHUB_RUN_ID and GITHUB_TOKEN set (missing: ${missing.join(', ') || 'none'}); nightly-failure-message.mjs <workflow file>[=<job that runs the checks>]..., or NEEDS and RELEASE set and nightly-failure-message.mjs --release <gate job>=<its name in the message>...`);
  }
  const message = await nightlyFailureMessage({
    fetch,
    api: env.GITHUB_API_URL || 'https://api.github.com',
    token: env.GITHUB_TOKEN,
    repo: env.GITHUB_REPOSITORY,
    sha: env.GITHUB_SHA,
    runId: env.GITHUB_RUN_ID,
    sources: args.map(source),
  });
  out.write(`${message}\n`);
}

export { LISTED, main, nightlyFailureMessage };

if (process.argv[1] !== undefined && fs.realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    await main(process.argv.slice(2), process.env);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
