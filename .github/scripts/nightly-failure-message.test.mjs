import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { main } from './nightly-failure-message.mjs';

const REPO = 'clerk/clerk-ios';
const API = 'https://api.github.test';
const sha = name => Buffer.from(name).toString('hex').padEnd(40, 'f');
const RELEASE_JOB = 'Verify end-to-end tests / Run verify end-to-end tests on iOS';

function fakeGitHub({ parents, runs = {}, jobs = {}, pulls = {} }) {
  const known = new Set([...Object.keys(parents), ...Object.values(parents)]);
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
    const notFound = { ok: false, status: 404, json: async () => ({}), text: async () => 'Not Found' };
    let match = /^\/actions\/workflows\/([\w.-]+)\/runs$/.exec(path);
    if (match) {
      assert.equal(searchParams.get('status'), 'success');
      return reply({ workflow_runs: runs[match[1]] ?? [] });
    }
    match = /^\/actions\/runs\/(\d+)\/jobs$/.exec(path);
    if (match) {
      return reply({ jobs: jobs[match[1]] ?? [] });
    }
    match = /^\/compare\/(\w+)\.\.\.(\w+)$/.exec(path);
    if (match) {
      const [, base, head] = match;
      if (!known.has(base) || !known.has(head)) {
        return notFound;
      }
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
    return notFound;
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
  await main(['verify-e2e.yml', `release-sdk.yml=${RELEASE_JOB}`], { GITHUB_API_URL: API, GITHUB_REPOSITORY: REPO, GITHUB_SHA: sha(failing), GITHUB_RUN_ID: '999', GITHUB_TOKEN: 'test-token' }, {
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
    const github = fakeGitHub({ parents: history(...names), runs: { 'verify-e2e.yml': [run(7, 'c0', '2026-10-01T07:17:00Z')] }, pulls });
    const lines = (await message(github, 'c150')).trimEnd().split('\n');
    assert.deepEqual(
      [lines.length, lines[1], lines[20], lines[21]],
      [22, `• <https://github.com/${REPO}/pull/1149|#1149 Change 149> · mikepitre`, `• <https://github.com/${REPO}/pull/1130|#1130 Change 130> · mikepitre`, 'and 130 more'],
    );
  });

  it('lists all 20 and counts nothing more when exactly 20 were merged', async () => {
    const names = Array.from({ length: 21 }, (_, at) => `c${at}`);
    const pulls = Object.fromEntries(names.slice(1).map((name, at) => [sha(name), [pull(1000 + at, name, `Change ${at}`, 'mikepitre')]]));
    const github = fakeGitHub({ parents: history(...names), runs: { 'verify-e2e.yml': [run(7, 'c0', '2026-10-01T07:17:00Z')] }, pulls });
    const lines = (await message(github, 'c20')).trimEnd().split('\n');
    assert.deepEqual([lines.length, lines[20]], [21, `• <https://github.com/${REPO}/pull/1000|#1000 Change 0> · mikepitre`]);
  });

  it('lists a pull request once when more than one of its commits was merged', async () => {
    const twoCommits = pull(702, 'a3', 'Two commits, merged by a rebase', 'mikepitre');
    const github = fakeGitHub({
      parents: history('a1', 'a2', 'a3'),
      runs: { 'verify-e2e.yml': [run(41, 'a1', '2026-10-13T07:17:00Z')] },
      pulls: { [sha('a2')]: [twoCommits], [sha('a3')]: [twoCommits] },
    });
    assert.equal(
      await message(github, 'a3'),
      [`Merged since the <https://github.com/${REPO}/actions/runs/41|last passing run> (2026-10-13 07:17 UTC):`, `• <https://github.com/${REPO}/pull/702|#702 Two commits, merged by a rebase> · mikepitre`, ''].join('\n'),
    );
  });

  it('names the pull request that merged a commit to main, not an earlier merged one that also held it', async () => {
    const github = fakeGitHub({
      parents: history('a1', 'a2'),
      runs: { 'verify-e2e.yml': [run(41, 'a1', '2026-10-13T07:17:00Z')] },
      pulls: { [sha('a2')]: [pull(650, 'zz', 'A pull request into another branch that held this commit', 'someone'), pull(702, 'a2', 'Two', 'mikepitre')] },
    });
    assert.equal(
      await message(github, 'a2'),
      [`Merged since the <https://github.com/${REPO}/actions/runs/41|last passing run> (2026-10-13 07:17 UTC):`, `• <https://github.com/${REPO}/pull/702|#702 Two> · mikepitre`, ''].join('\n'),
    );
  });

  it('skips a passing run on a commit that GitHub no longer has', async () => {
    const github = fakeGitHub({
      parents: history('a1', 'a2'),
      runs: { 'verify-e2e.yml': [run(42, 'gone', '2026-10-13T20:00:00Z', 'workflow_dispatch'), run(41, 'a1', '2026-10-13T07:17:00Z')] },
      pulls: { [sha('a2')]: [pull(702, 'a2', 'Two', 'mikepitre')] },
    });
    assert.equal(
      await message(github, 'a2'),
      [`Merged since the <https://github.com/${REPO}/actions/runs/41|last passing run> (2026-10-13 07:17 UTC):`, `• <https://github.com/${REPO}/pull/702|#702 Two> · mikepitre`, ''].join('\n'),
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
      jobs: { 62: [{ name: 'Prepare release commit', conclusion: 'success' }, { name: RELEASE_JOB, conclusion: 'success' }] },
      pulls: { [sha('a2')]: [pull(702, 'a2', 'Two', 'mikepitre')], [sha('a3')]: [pull(703, 'a3', 'Three', 'swolfand')] },
    });
    assert.equal(
      await message(github, 'a3'),
      [`Merged since the <https://github.com/${REPO}/actions/runs/62|last passing run> (2026-10-12 15:40 UTC):`, `• <https://github.com/${REPO}/pull/703|#703 Three> · swolfand`, ''].join('\n'),
    );
  });

  it('does not count a run of the release workflow that skipped the checks, or that ran before the release ran them', async () => {
    const github = fakeGitHub({
      parents: history('a1', 'a2', 'a3'),
      runs: {
        'verify-e2e.yml': [run(61, 'a1', '2026-10-12T07:17:00Z')],
        'release-sdk.yml': [run(63, 'a2', '2026-10-12T18:00:00Z', 'release', 'v1.4.1'), run(62, 'a2', '2026-10-12T15:40:00Z', 'workflow_dispatch')],
      },
      jobs: { 63: [{ name: RELEASE_JOB, conclusion: 'skipped' }], 62: [{ name: 'Push, tag, and publish release', conclusion: 'success' }] },
      pulls: { [sha('a2')]: [pull(702, 'a2', 'Two', 'mikepitre')], [sha('a3')]: [pull(703, 'a3', 'Three', 'swolfand')] },
    });
    const lines = (await message(github, 'a3')).split('\n');
    assert.deepEqual([lines[0], lines.length], [`Merged since the <https://github.com/${REPO}/actions/runs/61|last passing run> (2026-10-12 07:17 UTC):`, 4]);
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

describe('the gates named in the message about a blocked release', () => {
  const GATES = ['verify=unit tests and lint', 'integration-test=integration tests', 'paparazzi-verify=Paparazzi screenshot tests'];

  async function blocked(results, release = 'v1.2.3') {
    let written = '';
    const needs = Object.fromEntries(Object.entries(results).map(([job, result]) => [job, { result, outputs: {} }]));
    await main(['--release', ...GATES], { NEEDS: JSON.stringify(needs), RELEASE: release }, { out: { write: text => (written += text) } });
    return written;
  }

  it('names the release and the gate that failed', async () => {
    assert.equal(await blocked({ verify: 'success', 'integration-test': 'success', 'paparazzi-verify': 'failure' }), 'v1.2.3 release blocked: Paparazzi screenshot tests failed\n');
  });

  it('names every gate that failed, in the order the workflow gives them', async () => {
    assert.equal(
      await blocked({ verify: 'failure', 'integration-test': 'failure', 'paparazzi-verify': 'failure' }),
      'v1.2.3 release blocked: unit tests and lint, integration tests, and Paparazzi screenshot tests failed\n',
    );
  });

  it('says a gate that ran out of time or was cancelled got cancelled or timed out, not that it failed', async () => {
    assert.equal(await blocked({ verify: 'success', 'integration-test': 'cancelled', 'paparazzi-verify': 'success' }), 'v1.2.3 release blocked: integration tests got cancelled or timed out\n');
  });

  it('names the gates that failed and then the gates that got cancelled or timed out', async () => {
    assert.equal(
      await blocked({ verify: 'cancelled', 'integration-test': 'failure', 'paparazzi-verify': 'cancelled' }),
      'v1.2.3 release blocked: integration tests failed; unit tests and lint and Paparazzi screenshot tests got cancelled or timed out\n',
    );
  });

  it('escapes the release for Slack, and leaves it out when there is none', async () => {
    const failed = { verify: 'failure', 'integration-test': 'success', 'paparazzi-verify': 'success' };
    assert.deepEqual(
      [await blocked(failed, 'v1.2.3-<b>&<a>'), await blocked(failed, '')],
      ['v1.2.3-&lt;b&gt;&amp;&lt;a&gt; release blocked: unit tests and lint failed\n', 'release blocked: unit tests and lint failed\n'],
    );
  });

  it('fails when every gate passed or was skipped, so the alert does not name a gate that did not stop the release', async () => {
    await assert.rejects(blocked({ verify: 'success', 'integration-test': 'skipped', 'paparazzi-verify': 'success' }), /no gate failed or was cancelled/);
  });
});
