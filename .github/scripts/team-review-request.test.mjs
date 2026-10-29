import assert from 'node:assert/strict';
import fs from 'node:fs';
import { describe, it } from 'node:test';

import { main, parseTeam, ratedHighRisk } from './team-review-request.mjs';

const REPO = 'clerk/clerk-ios';
const API = 'https://api.github.test';
const HEAD = 'c14cacc2763d2dfc271d9c286b09376a90c5b9ff';
const TEAM = '# Team Mobile\nmikepitre\nseanperez29\nswolfand\nwobsoriano\n';
const ROLES = { mikepitre: 'admin', seanperez29: 'admin', swolfand: 'maintain', wobsoriano: 'maintain', 'outside-dev': 'write' };

// The shape CodeRabbit writes into its summary comment.
const riskComment = (level, commit = HEAD) => ({
  user: { login: 'coderabbitai[bot]' },
  body: `<!-- final_review_risk_start -->\n<!-- final_review_risk_label\n**Merge Risk:** **🔴 ${level}** · up to \`${commit.slice(0, 5)}\`\n-->\n<!-- final_review_risk_coverage:{"sourceCommitId":"${commit}","coveredCommitId":"${commit}","kind":"reviewed"} -->\n<!-- final_review_risk_end -->`,
});
const review = (login, state) => ({ user: { login }, state });

function fakeGitHub({ author = 'outside-dev', draft = false, state = 'open', files = [{ filename: 'Sources/ClerkKit/Clerk.swift' }], pending = [], reviews = [], comments = [] }) {
  const requested = [];
  const reply = body => ({ ok: true, status: 200, json: async () => body, text: async () => JSON.stringify(body) });
  const notFound = { ok: false, status: 404, json: async () => ({}), text: async () => 'Not Found' };
  const fetch = async (url, { method = 'GET', body }) => {
    const { pathname, searchParams } = new URL(url);
    const path = pathname.replace(`/repos/${REPO}`, '');
    if (method === 'POST' && path === '/pulls/7/requested_reviewers') {
      requested.push(...JSON.parse(body).reviewers);
      return reply({});
    }
    if (path === '/pulls/7') {
      return reply({ state, draft, user: { login: author }, head: { sha: HEAD }, base: { ref: 'main' }, changed_files: files.length, requested_reviewers: pending.map(login => ({ login })) });
    }
    if (path === '/contents/.github/protected-paths') {
      return reply({ content: Buffer.from('/.github/workflows/\n').toString('base64') });
    }
    const lists = { '/pulls/7/files': files, '/pulls/7/reviews': reviews, '/issues/7/comments': comments };
    if (path in lists) {
      const page = Number(searchParams.get('page'));
      return reply(lists[path].slice((page - 1) * 100, page * 100));
    }
    const match = /^\/collaborators\/([^/]+)\/permission$/.exec(path);
    if (match) {
      return match[1] in ROLES ? reply({ role_name: ROLES[match[1]] }) : notFound;
    }
    throw new Error(`unexpected ${method} ${path}`);
  };
  return { fetch, requested };
}

async function run(github) {
  const { fetch, requested } = fakeGitHub(github);
  const lines = [];
  await main(
    { GITHUB_API_URL: API, GITHUB_REPOSITORY: REPO, GITHUB_TOKEN: 'test-token', PR_NUMBER: '7' },
    { fetch, out: { write: line => lines.push(line) }, teamText: TEAM },
  );
  return { requested, output: lines.join('') };
}

describe('ratedHighRisk', () => {
  it('reads a high or critical rating for the head commit', () => {
    assert.equal(ratedHighRisk([riskComment('High')], HEAD), true);
    assert.equal(ratedHighRisk([riskComment('Critical')], HEAD), true);
  });

  it('ignores a lower rating, a rating of an older commit, and the same text from someone else', () => {
    assert.equal(ratedHighRisk([riskComment('Moderate')], HEAD), false);
    assert.equal(ratedHighRisk([riskComment('High', 'e225ce56d448093f7910a36cf47bcc9a664e04d0')], HEAD), false);
    assert.equal(ratedHighRisk([{ ...riskComment('High'), user: { login: 'outside-dev' } }], HEAD), false);
  });
});

describe('team review request', () => {
  it('lists GitHub logins in the committed team file', () => {
    const team = parseTeam(fs.readFileSync(new URL('../team-mobile', import.meta.url), 'utf8'));
    assert.ok(team.length > 0);
    assert.ok(team.every(login => /^[A-Za-z0-9-]+$/.test(login)));
  });

  it('requests nobody for a Team Mobile author on ordinary files while CodeRabbit reviews', async () => {
    const { requested, output } = await run({ author: 'swolfand' });
    assert.deepEqual(requested, []);
    assert.match(output, /Waiting on CodeRabbit/);
  });

  it('requests the other members when CodeRabbit rates a Team Mobile author\'s commit high risk', async () => {
    const { requested, output } = await run({ author: 'swolfand', comments: [riskComment('High')] });
    assert.deepEqual(requested, ['mikepitre', 'seanperez29', 'wobsoriano']);
    assert.match(output, /CodeRabbit rated this commit high or critical risk/);
  });

  it('requests the other members when a Team Mobile author changes a protected file', async () => {
    const { requested } = await run({ author: 'mikepitre', files: [{ filename: '.github/workflows/pr-ci.yml' }] });
    assert.deepEqual(requested, ['seanperez29', 'swolfand', 'wobsoriano']);
  });

  it('requests Team Mobile for an author with write access, a fork contributor and a bot', async () => {
    for (const author of ['outside-dev', 'fork-contributor', 'dependabot[bot]']) {
      const { requested } = await run({ author });
      assert.deepEqual(requested, ['mikepitre', 'seanperez29', 'swolfand', 'wobsoriano']);
    }
  });

  it('skips members who are already requested or have reviewed', async () => {
    const { requested } = await run({ pending: ['mikepitre'], reviews: [review('swolfand', 'COMMENTED')] });
    assert.deepEqual(requested, ['seanperez29', 'wobsoriano']);
  });

  it('requests nobody once Team Mobile approved', async () => {
    const { requested } = await run({ reviews: [review('wobsoriano', 'APPROVED')] });
    assert.deepEqual(requested, []);
  });

  it('skips drafts and closed pull requests', async () => {
    for (const github of [{ draft: true }, { state: 'closed' }]) {
      const { requested } = await run(github);
      assert.deepEqual(requested, []);
    }
  });
});
