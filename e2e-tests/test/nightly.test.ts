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

type Result = 'success' | 'failure' | 'cancelled' | 'skipped';

function runs(name: string, context: { event: string; repository?: string; results?: Record<string, Result>; runCancelled?: boolean }): boolean {
  const text = job(name);
  const condition = (/^ {4}if: (.+)$/m.exec(text)?.[1] ?? 'true').replace(/^\$\{\{ (.+) \}\}$/, '$1');
  const block = /^ {4}needs:(?: ([\w-]+)$|\n((?: {6}- [\w-]+\n)+))/m.exec(text);
  const needs = block?.[1] !== undefined ? [block[1]] : (block?.[2] ?? '').trim().split('\n').filter(Boolean).map((line) => line.replace(/^\s*- /, ''));
  const results = needs.map((need) => context.results?.[need] ?? 'success');
  const runCancelled = context.runCancelled ?? false;
  const script = (/\b(always|cancelled|failure|success)\(\)/.test(condition) ? condition : `success() && (${condition})`)
    .replaceAll('needs.*.result', JSON.stringify(results))
    .replaceAll('github.event_name', JSON.stringify(context.event))
    .replaceAll('github.repository', JSON.stringify(context.repository ?? 'clerk/clerk-ios'))
    .replaceAll(' != ', ' !== ')
    .replaceAll(' == ', ' === ');
  return new Function('always', 'cancelled', 'failure', 'success', 'contains', `return ${script};`)(
    () => true,
    () => runCancelled,
    () => results.includes('failure'),
    () => !runCancelled && results.every((result) => result === 'success'),
    (list: string[], item: string) => list.includes(item),
  ) as boolean;
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
  it('run every night at 07:17 UTC, before each release, and when a person starts them', () => {
    assert.match(triggers, /^ {2}schedule:\n {4}- cron: "17 7 \* \* \*"$/m);
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

describe('a step that hangs', () => {
  it('ends at the time limit of its own step, well before the time limit of the job', () => {
    const e2e = job('e2e-tests');
    const steps = e2e.split(/\n(?= {6}- name: )/).filter((step) => /"\$CLI" (up|run) /.test(step));
    assert.deepEqual(
      {
        job: Number(/^ {4}timeout-minutes: (\d+)$/m.exec(e2e)?.[1]),
        steps: steps.map((step) => [/- name: (.+)/.exec(step)?.[1], Number(/^ {8}timeout-minutes: (\d+)$/m.exec(step)?.[1])]),
      },
      { job: 90, steps: [['Build E2EHost and boot a simulator', 25], ['Run the end-to-end tests', 45]] },
    );
  });
});

describe('the Slack message about a failed nightly run', () => {
  it('is sent when a scheduled run fails, runs out of time, or is cancelled, and not for a release, a run a person started, a run that passed, or a fork', () => {
    assert.ok(job('notify').length > 0, 'the workflow has a notify job');
    assert.deepEqual(
      {
        'a scheduled run whose tests failed': runs('notify', { event: 'schedule', results: { 'e2e-tests': 'failure' } }),
        'a scheduled run that could not start': runs('notify', { event: 'schedule', results: { plan: 'failure', 'e2e-tests': 'skipped' } }),
        'a scheduled run that ran out of time': runs('notify', { event: 'schedule', results: { 'e2e-tests': 'cancelled' } }),
        'a scheduled run that was cancelled': runs('notify', { event: 'schedule', results: { 'e2e-tests': 'cancelled' }, runCancelled: true }),
        'a scheduled run that passed': runs('notify', { event: 'schedule' }),
        'a scheduled run in a fork': runs('notify', { event: 'schedule', results: { plan: 'skipped', 'e2e-tests': 'skipped' } }),
        'a release, or a run a person started, that failed': runs('notify', { event: 'workflow_dispatch', results: { 'e2e-tests': 'failure' } }),
        'a run a person started that was cancelled': runs('notify', { event: 'workflow_dispatch', results: { 'e2e-tests': 'cancelled' }, runCancelled: true }),
      },
      {
        'a scheduled run whose tests failed': true,
        'a scheduled run that could not start': true,
        'a scheduled run that ran out of time': true,
        'a scheduled run that was cancelled': true,
        'a scheduled run that passed': false,
        'a scheduled run in a fork': false,
        'a release, or a run a person started, that failed': false,
        'a run a person started that was cancelled': false,
      },
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
