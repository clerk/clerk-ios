import '@clerk/internal-mobile-e2e/testing/git-env';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, it } from 'node:test';

const workflow = readFileSync(join(import.meta.dirname, '..', '..', '.github', 'workflows', 'checks.yml'), 'utf8');
const notify = workflow.split(/\n(?= {2}[\w-]+:\n)/).find((text) => text.startsWith('  notify:\n')) ?? '';

function notifies(result: string, repository = 'clerk/clerk-ios'): boolean {
  const condition = /^ {4}if: >-\n((?: {6}.+\n)+)/m.exec(notify)?.[1] ?? assert.fail('no if on the notify job');
  const script = condition
    .replace(/\s+/g, ' ')
    .replaceAll('needs.checks.result', JSON.stringify(result))
    .replaceAll('github.repository', JSON.stringify(repository))
    .replaceAll(' == ', ' === ');
  return new Function('always', `return ${script};`)(() => true) as boolean;
}

function posted(webhook: string, commitMessage: string): { status: number | null; stdout: string; payload: unknown } {
  const step = notify.slice(notify.indexOf('run: |') + 'run: |'.length).split('\n').map((line) => line.trim()).join('\n');
  const work = mkdtempSync(join(tmpdir(), 'main-checks-notify-'));
  mkdirSync(join(work, 'bin'));
  writeFileSync(join(work, 'bin', 'curl'), `#!/bin/sh\nwhile [ "$#" -gt 1 ]; do [ "$1" = --data ] && printf '%s' "$2" > "${work}/posted"; shift; done\n`, { mode: 0o755 });
  const ran = spawnSync('bash', ['-c', step], {
    env: {
      PATH: `${join(work, 'bin')}:${process.env.PATH}`,
      SLACK_MOBILE_TEAM_ALERTS_WEBHOOK_URL: webhook,
      COMMIT_MESSAGE: commitMessage,
      GITHUB_SERVER_URL: 'https://github.com',
      GITHUB_REPOSITORY: 'clerk/clerk-ios',
      GITHUB_RUN_ID: '123',
      GITHUB_SHA: '132431494abcdef0123456789abcdef012345678',
    },
    encoding: 'utf8',
    timeout: 20_000,
  });
  let payload: unknown = null;
  try {
    payload = JSON.parse(readFileSync(join(work, 'posted'), 'utf8'));
  } catch {}
  rmSync(work, { recursive: true, force: true });
  return { status: ran.status, stdout: ran.stdout, payload };
}

describe('the Slack message about failed checks on main', () => {
  it('is sent when the checks of a push to main fail or are cancelled, and not when they pass or in a fork', () => {
    assert.deepEqual(
      { failure: notifies('failure'), cancelled: notifies('cancelled'), success: notifies('success'), fork: notifies('failure', 'someone/clerk-ios') },
      { failure: true, cancelled: true, success: false, fork: false },
    );
  });

  it('links the commit and the run and names the commit by its first line, escaped for Slack', () => {
    assert.deepEqual(posted('https://hooks.slack.test/T/B/x', 'fix(config): reject an <empty> key & more (#729)\n\nThe body.'), {
      status: 0,
      stdout: '',
      payload: {
        text: ':red_circle: clerk/clerk-ios main checks failed on <https://github.com/clerk/clerk-ios/commit/132431494abcdef0123456789abcdef012345678|132431494> fix(config): reject an &lt;empty&gt; key &amp; more (#729) · <https://github.com/clerk/clerk-ios/actions/runs/123|View the run>',
        unfurl_links: false,
        unfurl_media: false,
      },
    });
  });

  it('is skipped with a warning when the repository has no Slack webhook', () => {
    assert.deepEqual(posted('', 'fix: something'), {
      status: 0,
      stdout: '::warning::SLACK_MOBILE_TEAM_ALERTS_WEBHOOK_URL is not configured; skipping Slack notification\n',
      payload: null,
    });
  });
});
