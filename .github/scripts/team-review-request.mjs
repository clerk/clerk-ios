import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

import { codeOwnerApproval } from './code-owner-approval.mjs';
import { client, paged } from './github.mjs';

const TEAM_FILE = new URL('../team-mobile', import.meta.url);
const CODERABBIT = 'coderabbitai[bot]';
const HIGH_RISK = new Set(['high', 'critical']);

function parseTeam(text) {
  return text
    .split('\n')
    .map(line => line.replace(/#.*$/, '').trim())
    .filter(line => line !== '');
}

// CodeRabbit's summary comment carries its merge risk for the commit it last reviewed, and rewrites it after each review.
function ratedHighRisk(comments, head) {
  return comments.some(comment => {
    if (comment.user?.login !== CODERABBIT) {
      return false;
    }
    const body = comment.body ?? '';
    const covered = /<!-- final_review_risk_coverage:(\{.*?\}) -->/.exec(body)?.[1];
    const level = /<!-- final_review_risk_label\s*\*\*Merge Risk:\*\*\s*\*\*[^A-Za-z]*([A-Za-z]+)\*\*/.exec(body)?.[1];
    return covered !== undefined && level !== undefined && JSON.parse(covered).coveredCommitId === head && HIGH_RISK.has(level.toLowerCase());
  });
}

function protectedComment(files) {
  const shown = files.slice(0, 20).map(file => `- \`${file}\``);
  if (files.length > 20) {
    shown.push(`- and ${files.length - 20} more`);
  }
  return [
    "This pull request changes files listed in `.github/protected-paths`, so it needs an approval from another Team Mobile member before it can merge. CodeRabbit's approval isn't enough for these files.",
    '',
    ...shown,
  ].join('\n');
}

async function teamReviewRequest({ fetch, api, token, repo, number, team }) {
  const get = client({ fetch, api, token, repo });
  const pull = await get(`/pulls/${number}`);
  if (pull.state !== 'open' || pull.draft) {
    return 'The pull request is closed or a draft.';
  }
  const author = pull.user.login;
  const check = await codeOwnerApproval({ fetch, api, token, repo, number, author, baseRef: pull.base.ref });
  if (check.pass) {
    return `No review request needed. ${check.message}`;
  }
  if (check.reason === 'coderabbit' && !ratedHighRisk(await paged(get, `/issues/${number}/comments`), pull.head.sha)) {
    return 'Waiting on CodeRabbit, which hasn\'t rated this commit high or critical risk.';
  }
  const asked = new Set([author, ...pull.requested_reviewers.map(user => user.login)]);
  for (const review of await paged(get, `/pulls/${number}/reviews`)) {
    asked.add(review.user?.login);
  }
  const reviewers = team.filter(login => !asked.has(login));
  if (reviewers.length === 0) {
    return 'Every Team Mobile member is already requested or has reviewed.';
  }
  await get(`/pulls/${number}/requested_reviewers`, { method: 'POST', body: { reviewers } });
  if (check.reason === 'protected') {
    await get(`/issues/${number}/comments`, { method: 'POST', body: { body: protectedComment(check.files) } });
  }
  const why = check.reason === 'coderabbit' ? 'CodeRabbit rated this commit high or critical risk.' : check.message;
  return `Requested ${reviewers.join(', ')}. ${why}`;
}

async function main(env, { fetch = globalThis.fetch, out = process.stdout, teamText = fs.readFileSync(TEAM_FILE, 'utf8') } = {}) {
  const missing = ['GITHUB_REPOSITORY', 'GITHUB_TOKEN', 'PR_NUMBER'].filter(name => !env[name]);
  if (missing.length > 0) {
    throw new Error(`missing ${missing.join(', ')}`);
  }
  const message = await teamReviewRequest({
    fetch,
    api: env.GITHUB_API_URL || 'https://api.github.com',
    token: env.GITHUB_TOKEN,
    repo: env.GITHUB_REPOSITORY,
    number: env.PR_NUMBER,
    team: parseTeam(teamText),
  });
  out.write(`${message}\n`);
}

export { main, parseTeam, ratedHighRisk };

if (process.argv[1] !== undefined && fs.realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    await main(process.env);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
