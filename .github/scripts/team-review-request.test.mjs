import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { approvalWithheld, main } from './team-review-request.mjs';

const REPO = 'clerk/clerk-ios';
const API = 'https://api.github.test';
const HEAD = 'c14cacc2763d2dfc271d9c286b09376a90c5b9ff';

const notice = (title, commit = HEAD.slice(0, 12)) =>
  `## Walkthrough\n<!-- approval_notice_start -->\n**${title}**\n\nMerge risk is above the limit.\n\nCommit: \`${commit}\`.\n<!-- approval_notice_end -->\n`;
const coderabbit = body => ({ user: { login: 'coderabbitai[bot]' }, body });
const review = (login, state) => ({ user: { login }, state });

function fakeGitHub({ author = 'mikepitre', type = 'User', draft = false, state = 'open', teams = [], files = [{ filename: 'Sources/ClerkKit/Clerk.swift' }], comments = [], reviews = [], roles = { mikepitre: 'admin' } }) {
  const requested = [];
  const reply = body => ({ ok: true, status: 200, json: async () => body, text: async () => JSON.stringify(body) });
  const notFound = { ok: false, status: 404, json: async () => ({}), text: async () => 'Not Found' };
  const fetch = async (url, { method = 'GET', body }) => {
    const { pathname, searchParams } = new URL(url);
    const path = pathname.replace(`/repos/${REPO}`, '');
    if (method === 'POST' && path === '/pulls/7/requested_reviewers') {
      requested.push(...JSON.parse(body).team_reviewers);
      return reply({});
    }
    if (path === '/pulls/7') {
      return reply({ state, draft, requested_teams: teams.map(slug => ({ slug })), user: { login: author, type }, head: { sha: HEAD }, base: { ref: 'main' }, changed_files: files.length });
    }
    if (path === '/contents/.github/protected-paths') {
      return reply({ content: Buffer.from('/.github/workflows/\n').toString('base64') });
    }
    const page = Number(searchParams.get('page'));
    const lists = { '/pulls/7/files': files, '/pulls/7/reviews': reviews, '/issues/7/comments': comments };
    if (path in lists) {
      return reply(lists[path].slice((page - 1) * 100, page * 100));
    }
    const match = /^\/collaborators\/([^/]+)\/permission$/.exec(path);
    if (match) {
      return match[1] in roles ? reply({ role_name: roles[match[1]] }) : notFound;
    }
    throw new Error(`unexpected ${method} ${path}`);
  };
  return { fetch, requested };
}

async function run(github) {
  const { fetch, requested } = fakeGitHub(github);
  const lines = [];
  await main({ GITHUB_API_URL: API, GITHUB_REPOSITORY: REPO, GITHUB_TOKEN: 'test-token', PR_NUMBER: '7' }, { fetch, out: { write: line => lines.push(line) } });
  return { requested, output: lines.join('') };
}

describe('approvalWithheld', () => {
  it('reads a withheld notice for the head commit', () => {
    assert.equal(approvalWithheld([coderabbit(notice('Automatic approval withheld'))], HEAD), true);
  });

  it('ignores a withheld notice for an older commit, a pending notice, and the same text from someone else', () => {
    assert.equal(approvalWithheld([coderabbit(notice('Automatic approval withheld', 'e225ce56d448'))], HEAD), false);
    assert.equal(approvalWithheld([coderabbit(notice('Automatic approval pending'))], HEAD), false);
    assert.equal(approvalWithheld([{ user: { login: 'outside-dev' }, body: notice('Automatic approval withheld') }], HEAD), false);
  });
});

describe('team review request', () => {
  it('requests nobody when CodeRabbit can approve', async () => {
    const { requested, output } = await run({ comments: [coderabbit(notice('Automatic approval pending'))] });
    assert.deepEqual(requested, []);
    assert.match(output, /no team review is needed/);
  });

  it('requests nobody when a trusted author changes a protected file', async () => {
    const { requested } = await run({ files: [{ filename: '.github/workflows/pr-ci.yml' }] });
    assert.deepEqual(requested, []);
  });

  it('requests the team when CodeRabbit withholds its approval of the head commit', async () => {
    const { requested, output } = await run({ comments: [coderabbit(notice('Automatic approval withheld'))] });
    assert.deepEqual(requested, ['team-mobile']);
    assert.match(output, /CodeRabbit withheld its approval of c14cacc2763d/);
  });

  it('requests the team for an untrusted author who changes a protected file, even after CodeRabbit approves', async () => {
    const { requested, output } = await run({
      author: 'outside-dev',
      files: [{ filename: '.github/workflows/pr-ci.yml' }],
      reviews: [review('coderabbitai[bot]', 'APPROVED')],
      roles: { 'outside-dev': 'write' },
    });
    assert.deepEqual(requested, ['team-mobile']);
    assert.match(output, /This changes 1 protected file/);
  });

  it('requests the team for a bot author that CodeRabbit skips', async () => {
    const { requested, output } = await run({ author: 'dependabot[bot]', type: 'Bot', roles: {} });
    assert.deepEqual(requested, ['team-mobile']);
    assert.match(output, /CodeRabbit doesn't review pull requests from dependabot\[bot\]/);
  });

  it('requests nobody once a person approved a bot pull request', async () => {
    const { requested } = await run({ author: 'dependabot[bot]', type: 'Bot', reviews: [review('swolfand', 'APPROVED')], roles: {} });
    assert.deepEqual(requested, []);
  });

  it('still requests the team when only a write-access person approved a protected change', async () => {
    const { requested } = await run({
      author: 'dependabot[bot]',
      type: 'Bot',
      files: [{ filename: '.github/workflows/pr-ci.yml' }],
      reviews: [review('writer', 'APPROVED')],
      roles: { writer: 'write' },
    });
    assert.deepEqual(requested, ['team-mobile']);
  });

  it('skips drafts, closed pull requests, and a team that is already requested', async () => {
    const withheld = [coderabbit(notice('Automatic approval withheld'))];
    for (const github of [{ draft: true }, { state: 'closed' }, { teams: ['team-mobile'] }]) {
      const { requested } = await run({ ...github, comments: withheld });
      assert.deepEqual(requested, []);
    }
  });
});
