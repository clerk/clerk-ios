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

async function lastPassingRun(get, { sha, runId, workflows }) {
  const listed = await Promise.all(
    workflows.map(file => get(`/actions/workflows/${encodeURIComponent(file)}/runs?status=success&exclude_pull_requests=true&per_page=${RUNS_PER_WORKFLOW}`)),
  );
  const runs = listed
    .flatMap(page => page.workflow_runs)
    .filter(run => ranFullSuiteOnMain(run) && String(run.id) !== String(runId))
    .sort((a, b) => startedAt(b).localeCompare(startedAt(a)));
  const ancestor = new Map();
  for (const run of runs) {
    if (!ancestor.has(run.head_sha)) {
      const compared = await get(`/compare/${run.head_sha}...${sha}?per_page=1`, { missing: { status: 'unrelated' } });
      ancestor.set(run.head_sha, compared.status === 'ahead' || compared.status === 'identical');
    }
    if (ancestor.get(run.head_sha)) {
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

async function nightlyFailureMessage({ fetch, api, token, repo, sha, runId, workflows }) {
  const get = client({ fetch, api, token, repo });
  const passing = await lastPassingRun(get, { sha, runId, workflows });
  if (passing === null) {
    return sinceLastPass(null, []);
  }
  const shas = await commitsBetween(get, passing.head_sha, sha);
  return sinceLastPass(passing, await mergedPullRequests(get, shas));
}

async function main(workflows, env, { fetch = globalThis.fetch, out = process.stdout } = {}) {
  const missing = ['GITHUB_REPOSITORY', 'GITHUB_SHA', 'GITHUB_RUN_ID', 'GITHUB_TOKEN'].filter(name => !env[name]);
  if (workflows.length === 0 || missing.length > 0) {
    throw new Error(`usage: GITHUB_REPOSITORY, GITHUB_SHA, GITHUB_RUN_ID and GITHUB_TOKEN set (missing: ${missing.join(', ') || 'none'}); nightly-failure-message.mjs <workflow file>...`);
  }
  const message = await nightlyFailureMessage({
    fetch,
    api: env.GITHUB_API_URL || 'https://api.github.com',
    token: env.GITHUB_TOKEN,
    repo: env.GITHUB_REPOSITORY,
    sha: env.GITHUB_SHA,
    runId: env.GITHUB_RUN_ID,
    workflows,
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
