import '../testing/git-env.ts';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, it } from 'node:test';

const workflow = readFileSync(join(import.meta.dirname, '..', '..', '.github', 'workflows', 'verify-e2e.yml'), 'utf8');
const triggers = workflow.slice(workflow.indexOf('\non:\n'), workflow.indexOf('\npermissions:'));
const jobs = workflow.split(/\n(?= {2}[\w-]+:\n)/);
const job = (name: string): string => jobs.find((text) => text.startsWith(`  ${name}:\n`)) ?? '';

function runs(name: string, context: { event: string; repository?: string; failed?: boolean }): boolean {
  const condition = /^ {4}if: (.+)$/m.exec(job(name))?.[1] ?? 'true';
  const script = condition
    .replaceAll('failure()', String(context.failed ?? false))
    .replaceAll('github.event_name', JSON.stringify(context.event))
    .replaceAll('github.repository', JSON.stringify(context.repository ?? 'clerk/clerk-ios'))
    .replaceAll(' != ', ' !== ')
    .replaceAll(' == ', ' === ');
  return new Function(`return ${script};`)() as boolean;
}

function notified(webhook: string): { status: number | null; stdout: string; posted: unknown } {
  const text = job('notify');
  const script = text.slice(text.indexOf('run: |') + 'run: |'.length).split('\n').map((line) => line.trim()).join('\n');
  const work = mkdtempSync(join(tmpdir(), 'verify-nightly-notify-'));
  mkdirSync(join(work, 'bin'));
  writeFileSync(join(work, 'bin', 'curl'), `#!/bin/sh\nwhile [ "$#" -gt 1 ]; do [ "$1" = --data ] && printf '%s' "$2" > "${work}/posted"; shift; done\necho "$1" > "${work}/url"\n`, { mode: 0o755 });
  const ran = spawnSync('bash', ['-c', script], {
    env: { PATH: `${join(work, 'bin')}:${process.env.PATH}`, SLACK_WEBHOOK_URL: webhook, GITHUB_SERVER_URL: 'https://github.com', GITHUB_REPOSITORY: 'clerk/clerk-ios', GITHUB_RUN_ID: '123' },
    encoding: 'utf8',
    timeout: 20_000,
  });
  let posted: unknown = null;
  try {
    posted = { url: readFileSync(join(work, 'url'), 'utf8').trim(), payload: JSON.parse(readFileSync(join(work, 'posted'), 'utf8')) };
  } catch {}
  rmSync(work, { recursive: true, force: true });
  return { status: ran.status, stdout: ran.stdout, posted };
}

describe('when the end-to-end tests run', () => {
  it('run every night at 07:00 UTC, before each release, and when a person starts them', () => {
    assert.match(triggers, /^ {2}schedule:\n {4}- cron: "0 7 \* \* \*"$/m);
    assert.match(triggers, /^ {2}workflow_call:$/m);
    assert.match(triggers, /^ {2}workflow_dispatch:$/m);
  });

  it('run on the schedule only in clerk/clerk-ios, so that the nightly run of a fork does nothing', () => {
    assert.ok(job('plan').length > 0, 'the workflow has a plan job');
    assert.deepEqual(
      [
        runs('plan', { event: 'schedule' }),
        runs('plan', { event: 'schedule', repository: 'someone/clerk-ios' }),
        runs('plan', { event: 'workflow_dispatch' }),
        runs('plan', { event: 'workflow_dispatch', repository: 'someone/clerk-ios' }),
      ],
      [true, false, true, true],
    );
  });
});

describe('the Slack message about a failed nightly run', () => {
  it('is sent only when a scheduled run fails, and not for a release, a run a person started, or a run that passed', () => {
    assert.ok(job('notify').length > 0, 'the workflow has a notify job');
    assert.deepEqual(
      [
        runs('notify', { event: 'schedule', failed: true }),
        runs('notify', { event: 'schedule', failed: false }),
        runs('notify', { event: 'workflow_dispatch', failed: true }),
      ],
      [true, false, false],
    );
  });

  it('names the repository and links the run', () => {
    assert.deepEqual(notified('https://hooks.slack.test/T/B/x'), {
      status: 0,
      stdout: '',
      posted: {
        url: 'https://hooks.slack.test/T/B/x',
        payload: {
          text: 'The nightly end-to-end tests failed in clerk/clerk-ios',
          blocks: [
            { type: 'section', text: { type: 'mrkdwn', text: '*The nightly end-to-end tests failed in clerk/clerk-ios*' } },
            { type: 'context', elements: [{ type: 'mrkdwn', text: '<https://github.com/clerk/clerk-ios/actions/runs/123|View the run>' }] },
          ],
        },
      },
    });
  });

  it('is skipped with a warning when the repository has no Slack webhook', () => {
    assert.deepEqual(notified(''), { status: 0, stdout: '::warning::SLACK_WEBHOOK_URL is not configured; skipping Slack notification\n', posted: null });
  });
});
