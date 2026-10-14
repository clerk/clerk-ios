import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { main } from './nightly-failure-message.mjs';

const REPO = 'clerk/clerk-ios';
const API = 'https://api.github.test';
const sha = name => Buffer.from(name).toString('hex').padEnd(40, 'f');

function fakeGitHub({ parents, runs = {}, pulls = {} }) {
  const ancestors = head => {
    const line = [];
    for (let at = head; at !== undefined; at = parents[at]) {
      line.push(at);
    }
    return line;
  };
  const requests = [];
  const fetch = async (url, { headers }) => {
    assert.equal(headers.authorization, 'Bearer test-token');
    const { pathname, searchParams } = new URL(url);
    const path = pathname.replace(`/repos/${REPO}`, '');
    requests.push(path);
    const reply = body => ({ ok: true, status: 200, json: async () => body, text: async () => JSON.stringify(body) });
    let match = /^\/actions\/workflows\/([\w.-]+)\/runs$/.exec(path);
    if (match) {
      assert.equal(searchParams.get('status'), 'success');
      return reply({ workflow_runs: runs[match[1]] ?? [] });
    }
    match = /^\/compare\/(\w+)\.\.\.(\w+)$/.exec(path);
    if (match) {
      const [, base, head] = match;
      const headLine = ancestors(head);
      if (!headLine.includes(base)) {
        return reply({ status: ancestors(base).includes(head) ? 'behind' : 'diverged', total_commits: 0, commits: [] });
      }
      const between = headLine.slice(0, headLine.indexOf(base)).reverse();
      const perPage = Number(searchParams.get('per_page'));
      const page = Number(searchParams.get('page') ?? 1);
      return reply({
        status: between.length === 0 ? 'identical' : 'ahead',
        total_commits: between.length,
        commits: between.slice((page - 1) * perPage, page * perPage).map(commit => ({ sha: commit })),
      });
    }
    match = /^\/commits\/(\w+)\/pulls$/.exec(path);
    if (match) {
      return reply(pulls[match[1]] ?? []);
    }
    return { ok: false, status: 404, json: async () => ({}), text: async () => 'Not Found' };
  };
  return { fetch, requests };
}

const history = (...names) => Object.fromEntries(names.slice(1).map((name, at) => [sha(name), sha(names[at])]));

const run = (id, commit, startedAt, event = 'schedule', branch = 'main') => ({
  id,
  event,
  head_branch: branch,
  head_sha: sha(commit),
  run_started_at: startedAt,
  html_url: `https://github.com/${REPO}/actions/runs/${id}`,
});

const pull = (number, commit, title, login) => ({
  number,
  title,
  merged_at: '2026-10-13T12:00:00Z',
  merge_commit_sha: sha(commit),
  html_url: `https://github.com/${REPO}/pull/${number}`,
  user: { login },
});

async function message(github, failing) {
  let written = '';
  await main(['verify-e2e.yml', 'release-sdk.yml'], { GITHUB_API_URL: API, GITHUB_REPOSITORY: REPO, GITHUB_SHA: sha(failing), GITHUB_RUN_ID: '999', GITHUB_TOKEN: 'test-token' }, {
    fetch: github.fetch,
    out: { write: text => (written += text) },
  });
  return written;
}

describe('the list of pull requests in the message about a failed nightly run', () => {
  it('lists each pull request merged since the last passing run, newest first, with its author', async () => {
    const github = fakeGitHub({
      parents: history('a1', 'a2', 'a3', 'a4', 'a5'),
      runs: { 'verify-e2e.yml': [run(999, 'a5', '2026-10-14T07:17:00Z'), run(41, 'a2', '2026-10-13T07:17:30Z')] },
      pulls: {
        [sha('a3')]: [pull(703, 'a3', 'Fix the <SignIn> view & its title', 'swolfand')],
        [sha('a4')]: [{ ...pull(650, 'zz', 'An open pull request that also holds this commit', 'someone'), merged_at: null }],
        [sha('a5')]: [pull(705, 'a5', 'Add passkeys to the profile', 'mikepitre')],
      },
    });
    assert.equal(
      await message(github, 'a5'),
      [
        `Merged since the <https://github.com/${REPO}/actions/runs/41|last passing run> (2026-10-13 07:17 UTC):`,
        `• <https://github.com/${REPO}/pull/705|#705 Add passkeys to the profile> · mikepitre`,
        `• <https://github.com/${REPO}/pull/703|#703 Fix the &lt;SignIn&gt; view &amp; its title> · swolfand`,
        '',
      ].join('\n'),
    );
  });

  it('lists the newest 20 and counts the rest when more were merged', async () => {
    const names = Array.from({ length: 151 }, (_, at) => `c${at}`);
    const pulls = Object.fromEntries(names.slice(1).map((name, at) => [sha(name), [pull(1000 + at, name, `Change ${at}`, 'mikepitre')]]));
    const github = fakeGitHub({ parents: history(...names), runs: { 'release-sdk.yml': [run(7, 'c0', '2026-10-01T09:00:00Z')] }, pulls });
    const lines = (await message(github, 'c150')).trimEnd().split('\n');
    assert.deepEqual(
      [lines.length, lines[1], lines[20], lines[21]],
      [22, `• <https://github.com/${REPO}/pull/1149|#1149 Change 149> · mikepitre`, `• <https://github.com/${REPO}/pull/1130|#1130 Change 130> · mikepitre`, 'and 130 more'],
    );
  });

  it('says so in one line when no earlier run passed', async () => {
    const github = fakeGitHub({ parents: history('a1', 'a2'), runs: { 'verify-e2e.yml': [run(999, 'a2', '2026-10-14T07:17:00Z')] } });
    assert.equal(await message(github, 'a2'), 'No earlier passing run was found, so no pull requests are listed.\n');
  });

  it('ignores a newer passing run on a commit that the failed commit does not contain', async () => {
    const github = fakeGitHub({
      parents: { ...history('a1', 'a2', 'a3'), [sha('b1')]: sha('a2') },
      runs: { 'release-sdk.yml': [run(52, 'b1', '2026-10-13T20:00:00Z', 'release', 'v1.4.1')], 'verify-e2e.yml': [run(51, 'a1', '2026-10-12T07:17:00Z')] },
      pulls: { [sha('a2')]: [pull(702, 'a2', 'Two', 'mikepitre')], [sha('a3')]: [pull(703, 'a3', 'Three', 'swolfand')] },
    });
    assert.equal(
      await message(github, 'a3'),
      [
        `Merged since the <https://github.com/${REPO}/actions/runs/51|last passing run> (2026-10-12 07:17 UTC):`,
        `• <https://github.com/${REPO}/pull/703|#703 Three> · swolfand`,
        `• <https://github.com/${REPO}/pull/702|#702 Two> · mikepitre`,
        '',
      ].join('\n'),
    );
  });

  it('counts a run of the release workflow for a published release, when it is newer than the last passing nightly run', async () => {
    const github = fakeGitHub({
      parents: history('a1', 'a2', 'a3'),
      runs: { 'verify-e2e.yml': [run(61, 'a1', '2026-10-12T07:17:00Z')], 'release-sdk.yml': [run(62, 'a2', '2026-10-12T15:40:00Z', 'release', 'v1.4.0')] },
      pulls: { [sha('a2')]: [pull(702, 'a2', 'Two', 'mikepitre')], [sha('a3')]: [pull(703, 'a3', 'Three', 'swolfand')] },
    });
    assert.equal(
      await message(github, 'a3'),
      [`Merged since the <https://github.com/${REPO}/actions/runs/62|last passing run> (2026-10-12 15:40 UTC):`, `• <https://github.com/${REPO}/pull/703|#703 Three> · swolfand`, ''].join('\n'),
    );
  });

  it('ignores a pull request run and a run a person started on another branch, which did not test main', async () => {
    const github = fakeGitHub({
      parents: history('a1', 'a2', 'a3'),
      runs: {
        'verify-e2e.yml': [
          run(93, 'a2', '2026-10-13T21:00:00Z', 'pull_request', 'someone/change'),
          run(92, 'a2', '2026-10-13T20:00:00Z', 'workflow_dispatch', 'mike/try-this'),
          run(91, 'a1', '2026-10-12T07:17:00Z', 'workflow_dispatch'),
        ],
      },
      pulls: { [sha('a2')]: [pull(702, 'a2', 'Two', 'mikepitre')], [sha('a3')]: [pull(703, 'a3', 'Three', 'swolfand')] },
    });
    const lines = (await message(github, 'a3')).split('\n');
    assert.deepEqual([lines[0], lines.length], [`Merged since the <https://github.com/${REPO}/actions/runs/91|last passing run> (2026-10-12 07:17 UTC):`, 4]);
  });

  it('says that nothing was merged when the failed run tested the commit that last passed', async () => {
    const github = fakeGitHub({ parents: history('a1', 'a2'), runs: { 'verify-e2e.yml': [run(71, 'a2', '2026-10-13T07:17:00Z')] } });
    assert.equal(await message(github, 'a2'), `No pull requests were merged since the <https://github.com/${REPO}/actions/runs/71|last passing run> (2026-10-13 07:17 UTC).\n`);
  });

  it('fails instead of printing a partial list when GitHub refuses a request', async () => {
    const github = fakeGitHub({ parents: history('a1', 'a2'), runs: { 'verify-e2e.yml': [run(81, 'a1', '2026-10-13T07:17:00Z')] } });
    const refusing = async (url, init) => (url.includes('/pulls') ? { ok: false, status: 403, text: async () => 'Resource not accessible by integration' } : github.fetch(url, init));
    await assert.rejects(message({ fetch: refusing }, 'a2'), /\/commits\/6132f{36}\/pulls answered 403: Resource not accessible by integration/);
  });
});
