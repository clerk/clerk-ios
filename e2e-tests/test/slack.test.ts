import '../testing/git-env.ts';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, it } from 'node:test';

const WORKFLOWS = join(import.meta.dirname, '..', '..', '.github', 'workflows');
const read = (file: string): string => readFileSync(join(WORKFLOWS, file), 'utf8');
const job = (workflow: string, name: string): string => workflow.split(/\n(?= {2}[\w-]+:\n)/).find((text) => text.startsWith(`  ${name}:\n`)) ?? '';
const WEBHOOK = '${{ secrets.SLACK_MOBILE_TEAM_ALERTS_WEBHOOK_URL }}';

describe('the Slack posts of the workflows', () => {
  it('go to the mobile team alerts channel, so no workflow reads the old SLACK_WEBHOOK_URL secret', () => {
    const workflows = readdirSync(WORKFLOWS).filter((file) => /\.ya?ml$/.test(file));
    assert.ok(workflows.includes('notify-slack-release.yml'), workflows.join(', '));
    assert.deepEqual(workflows.filter((file) => /\bSLACK_WEBHOOK_URL\b/.test(read(file))), []);
  });
});

describe('the Slack announcement of a release', () => {
  const caller = job(read('bump-javascript-expo-ios-sdk.yml'), 'notify-slack-release');
  const announce = read('notify-slack-release.yml');
  const step = job(announce, 'notify').split(/\n(?= {6}- name: )/).find((text) => text.includes('- name: Notify Slack')) ?? '';

  function announced(webhook: string): { status: number | null; stdout: string; posted: unknown } {
    const run = step.slice(step.indexOf('run: |') + 'run: |'.length);
    const work = mkdtempSync(join(tmpdir(), 'release-notify-'));
    mkdirSync(join(work, 'bin'));
    writeFileSync(join(work, 'bin', 'curl'), `#!/bin/sh\nwhile [ "$#" -gt 1 ]; do [ "$1" = --data ] && printf '%s' "$2" > "${work}/posted"; shift; done\necho "$1" > "${work}/url"\n`, { mode: 0o755 });
    const ran = spawnSync('bash', ['-c', run], {
      env: {
        PATH: `${join(work, 'bin')}:${process.env.PATH}`,
        SLACK_MOBILE_TEAM_ALERTS_WEBHOOK_URL: webhook,
        RELEASE_TAG: '1.2.3',
        RELEASE_URL: 'https://github.com/clerk/clerk-ios/releases/tag/1.2.3',
        EXPO_BUMP_PR_URL: '',
        GITHUB_REPOSITORY: 'clerk/clerk-ios',
      },
      encoding: 'utf8',
      timeout: 20_000,
    });
    let posted: unknown = null;
    try {
      posted = { url: readFileSync(join(work, 'url'), 'utf8').trim(), payload: JSON.parse(readFileSync(join(work, 'posted'), 'utf8')).text };
    } catch {}
    rmSync(work, { recursive: true, force: true });
    return { status: ran.status, stdout: ran.stdout, posted };
  }

  it('gets the mobile team alerts webhook from the release workflow that calls it', () => {
    assert.deepEqual(
      {
        passed: /^ {4}secrets:\n((?: {6}.+\n?)+)/m.exec(caller)?.[1]?.trimEnd(),
        declared: /^ {4}secrets:\n((?: {6}.+\n)+)/m.exec(announce.slice(0, announce.indexOf('\njobs:')))?.[1]?.trimEnd(),
        read: /^ {10}SLACK_MOBILE_TEAM_ALERTS_WEBHOOK_URL: (.+)$/m.exec(step)?.[1],
      },
      {
        passed: `      SLACK_MOBILE_TEAM_ALERTS_WEBHOOK_URL: ${WEBHOOK}`,
        declared: '      SLACK_MOBILE_TEAM_ALERTS_WEBHOOK_URL:\n        required: false',
        read: WEBHOOK,
      },
    );
  });

  it('posts the release to that webhook', () => {
    assert.deepEqual(announced('https://hooks.slack.test/T/B/x'), {
      status: 0,
      stdout: '',
      posted: { url: 'https://hooks.slack.test/T/B/x', payload: 'Clerk iOS SDK 1.2.3 has been released' },
    });
  });
});
