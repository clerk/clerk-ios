import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

import { codeOwnerApproval, trusted } from './code-owner-approval.mjs';
import { client, paged } from './github.mjs';

const TEAM = 'team-mobile';
const CODERABBIT = 'coderabbitai[bot]';
const HIGH_RISK = new Set(['high', 'critical']);

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

const PROTECTED_NOTICE =
  "This pull request changes files listed in `.github/protected-paths`, so it needs an approval from another Team Mobile member before it can merge. CodeRabbit's approval isn't enough for these files.";

function protectedComment(files) {
  const shown = files.slice(0, 20).map(file => `- \`${file}\``);
  if (files.length > 20) {
    shown.push(`- and ${files.length - 20} more`);
  }
  return [PROTECTED_NOTICE, '', ...shown].join('\n');
}

async function teamReviewRequest({ fetch, api, token, teamToken, repo, number }) {
  const get = client({ fetch, api, token, repo });
  // Only the app token can see org teams, so it reads the team and makes the review request.
  const teamGet = client({ fetch, api, token: teamToken });
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
  if (check.reason === 'protected') {
    const comments = await paged(get, `/issues/${number}/comments`);
    const body = protectedComment(check.files);
    const notice = comments.find(comment => comment.body?.startsWith(PROTECTED_NOTICE));
    if (notice === undefined) {
      await get(`/issues/${number}/comments`, { method: 'POST', body: { body } });
    } else if (notice.body !== body) {
      await get(`/issues/comments/${notice.id}`, { method: 'PATCH', body: { body } });
    }
    if (!ratedHighRisk(comments, pull.head.sha)) {
      return `Requested nobody. ${check.message}`;
    }
  }
  const members = (await paged(teamGet, `/orgs/${repo.split('/')[0]}/teams/${TEAM}/members`)).map(user => user.login);
  // The team only grants write, and only members with maintain or admin can approve, so only they count as Team Mobile here.
  const team = (await Promise.all(members.map(async login => ((await trusted(get, login)) ? login : null)))).filter(login => login !== null);
  const pending = await teamGet(`/repos/${repo}/pulls/${number}/requested_reviewers`);
  const asked = new Set([author, ...pending.users.map(user => user.login)]);
  for (const review of await paged(get, `/pulls/${number}/reviews`)) {
    asked.add(review.user?.login);
  }
  if (pending.teams.some(requested => requested.slug === TEAM) || team.some(login => login !== author && asked.has(login))) {
    return 'Team Mobile is already requested, or a member is requested or has reviewed.';
  }
  await teamGet(`/repos/${repo}/pulls/${number}/requested_reviewers`, { method: 'POST', body: { team_reviewers: [TEAM] } });
  const why = check.reason === 'coderabbit' || check.reason === 'protected' ? 'CodeRabbit rated this commit high or critical risk.' : check.message;
  return `Requested @${repo.split('/')[0]}/${TEAM}. ${why}`;
}

async function main(env, { fetch = globalThis.fetch, out = process.stdout } = {}) {
  const missing = ['GITHUB_REPOSITORY', 'GITHUB_TOKEN', 'TEAM_REVIEW_TOKEN', 'PR_NUMBER'].filter(name => !env[name]);
  if (missing.length > 0) {
    throw new Error(`missing ${missing.join(', ')}`);
  }
  const message = await teamReviewRequest({
    fetch,
    api: env.GITHUB_API_URL || 'https://api.github.com',
    token: env.GITHUB_TOKEN,
    teamToken: env.TEAM_REVIEW_TOKEN,
    repo: env.GITHUB_REPOSITORY,
    number: env.PR_NUMBER,
  });
  out.write(`${message}\n`);
}

export { main, ratedHighRisk };

if (process.argv[1] !== undefined && fs.realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    await main(process.env);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
