import fs from 'node:fs';
import { fileURLToPath } from 'node:url';

import { approvers, codeOwnerApproval } from './code-owner-approval.mjs';
import { client, paged } from './github.mjs';

const TEAM = 'team-mobile';
const CODERABBIT = 'coderabbitai[bot]';

// CodeRabbit keeps one notice in its summary comment and rewrites it as each commit's review finishes.
function approvalWithheld(comments, head) {
  return comments.some(comment => {
    if (comment.user?.login !== CODERABBIT) {
      return false;
    }
    const notice = /<!-- approval_notice_start -->([\s\S]*?)<!-- approval_notice_end -->/.exec(comment.body ?? '')?.[1];
    if (notice === undefined || !/automatic approval withheld/i.test(notice)) {
      return false;
    }
    const commit = /Commit: `([0-9a-f]+)`/.exec(notice)?.[1];
    return commit === undefined || head.startsWith(commit);
  });
}

async function reasons({ fetch, api, token, repo, number, pull, get }) {
  const found = [];
  const author = pull.user.login;
  if (pull.user.type === 'Bot') {
    found.push(`CodeRabbit doesn't review pull requests from ${author}.`);
  }
  if (approvalWithheld(await paged(get, `/issues/${number}/comments`), pull.head.sha)) {
    found.push(`CodeRabbit withheld its approval of ${pull.head.sha.slice(0, 12)}.`);
  }
  // A person's approval is all GitHub needs for the two reasons above. Protected files need a trusted one, which the check decides.
  if (found.length > 0 && approvers(await paged(get, `/pulls/${number}/reviews`), author).some(login => !login.endsWith('[bot]'))) {
    found.length = 0;
  }
  const check = await codeOwnerApproval({ fetch, api, token, repo, number, author, baseRef: pull.base.ref });
  if (!check.pass) {
    found.push(check.message);
  }
  return found;
}

async function teamReviewRequest({ fetch, api, token, repo, number }) {
  const get = client({ fetch, api, token, repo });
  const pull = await get(`/pulls/${number}`);
  if (pull.state !== 'open' || pull.draft) {
    return 'The pull request is closed or a draft.';
  }
  if (pull.requested_teams.some(team => team.slug === TEAM)) {
    return `@clerk/${TEAM} is already requested.`;
  }
  const found = await reasons({ fetch, api, token, repo, number, pull, get });
  if (found.length === 0) {
    return 'CodeRabbit can approve this pull request, so no team review is needed.';
  }
  await get(`/pulls/${number}/requested_reviewers`, { method: 'POST', body: { team_reviewers: [TEAM] } });
  return `Requested @clerk/${TEAM}. ${found.join(' ')}`;
}

async function main(env, { fetch = globalThis.fetch, out = process.stdout } = {}) {
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
  });
  out.write(`${message}\n`);
}

export { approvalWithheld, main };

if (process.argv[1] !== undefined && fs.realpathSync(process.argv[1]) === fileURLToPath(import.meta.url)) {
  try {
    await main(process.env);
  } catch (error) {
    process.stderr.write(`${error.message}\n`);
    process.exitCode = 1;
  }
}
