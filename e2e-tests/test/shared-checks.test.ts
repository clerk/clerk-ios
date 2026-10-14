import '../testing/git-env.ts';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, it } from 'node:test';

const WORKFLOWS = join(import.meta.dirname, '..', '..', '.github', 'workflows');
const read = (file: string): string => readFileSync(join(WORKFLOWS, file), 'utf8');
const shared = read('shared-checks.yml');

function buildPlatforms(caller: string): string {
  const job = read(caller).split(/\n(?= {2}[\w-]+:\n)/).find((block) => block.includes('uses: ./.github/workflows/shared-checks.yml'));
  assert.ok(job, `${caller} calls shared-checks.yml`);
  const passed = /^ {6}build_platforms: '(.+)'$/m.exec(job)?.[1];
  const inputs = shared.slice(shared.indexOf('      build_platforms:'), shared.indexOf('    secrets:'));
  return passed ?? /^ {8}default: '(.+)'$/m.exec(inputs)?.[1] ?? 'no build_platforms input';
}

function script(step: string, workflow = shared): string {
  const lines = workflow.split('\n');
  const named = lines.findIndex((line) => line.trim() === `- name: ${step}`);
  const run = lines.findIndex((line, at) => at > named && line.trim() === 'run: |');
  const indent = lines[run]!.indexOf('run:');
  const body: string[] = [];
  for (const line of lines.slice(run + 1)) {
    if (line.trim() !== '' && line.search(/\S/) <= indent) break;
    body.push(line);
  }
  return body.join('\n');
}

function checkRuns(platforms: string, jobs: Readonly<Record<string, string>>): Record<string, string> {
  const work = mkdtempSync(join(tmpdir(), 'shared-checks-'));
  mkdirSync(join(work, 'bin'));
  writeFileSync(join(work, 'created'), '');
  writeFileSync(join(work, 'completed'), '');
  writeFileSync(join(work, 'output'), '');
  writeFileSync(join(work, 'jobs.json'), JSON.stringify({ jobs: Object.entries(jobs).map(([name, conclusion]) => ({ name: `Shared checks / ${name}`, conclusion })) }));
  writeFileSync(
    join(work, 'bin', 'gh'),
    `#!/bin/bash
method=GET; path=; name=; conclusion=
while [ $# -gt 0 ]; do
  case "$1" in
    api) ;;
    --method) method=$2; shift ;;
    -f) case "$2" in name=*) name=\${2#name=} ;; conclusion=*) conclusion=\${2#conclusion=} ;; esac; shift ;;
    --jq) shift ;;
    *) path=$1 ;;
  esac
  shift
done
case "$method" in
  POST) echo "$name" >> "${work}/created"; echo $((100 + $(wc -l < "${work}/created"))) ;;
  PATCH) echo "\${path##*/} $conclusion" >> "${work}/completed" ;;
  GET) cat "${work}/jobs.json" ;;
esac
`,
    { mode: 0o755 },
  );
  const env = {
    PATH: `${join(work, 'bin')}:${process.env.PATH}`,
    GITHUB_OUTPUT: join(work, 'output'),
    GITHUB_SERVER_URL: 'https://github.com',
    GITHUB_REPOSITORY: 'clerk/clerk-ios',
    GITHUB_RUN_ID: '42',
    CHECK_RUN_NAME_PREFIX: 'Manual CI',
    CHECK_RUN_SHA: 'a'.repeat(40),
    CHECK_RUN_TARGET_URL: '',
    BUILD_PLATFORMS: platforms,
  };
  const prepared = spawnSync('bash', ['-c', script('Create in-progress check runs')], { env, encoding: 'utf8', timeout: 20_000 });
  assert.equal(prepared.status, 0, prepared.stderr);
  const ids = /^check_runs_json=(.+)$/m.exec(readFileSync(join(work, 'output'), 'utf8'))?.[1] ?? '{}';
  const reported = spawnSync('bash', ['-c', script('Report final check runs')], { env: { ...env, CHECK_RUNS_JSON: ids }, encoding: 'utf8', timeout: 20_000 });
  assert.equal(reported.status, 0, reported.stderr);
  const conclusions = new Map(readFileSync(join(work, 'completed'), 'utf8').trim().split('\n').map((line) => line.split(' ') as [string, string]));
  const created = readFileSync(join(work, 'created'), 'utf8').trim().split('\n');
  rmSync(work, { recursive: true, force: true });
  return Object.fromEntries(created.map((name, at) => [name, conclusions.get(String(101 + at)) ?? 'in_progress']));
}

describe('the platforms the shared checks build', () => {
  it('are iOS and macOS for a pull request and for a push to main', () => {
    assert.deepEqual([buildPlatforms('run-pr-ci.yml'), buildPlatforms('checks.yml')], ['["iOS", "macOS"]', '["iOS", "macOS"]']);
  });

  it('are all six each night and for a release, so a break on macCatalyst, watchOS, tvOS or visionOS shows up by the next morning and stops the release', () => {
    const all = '["iOS", "macOS", "macCatalyst", "watchOS", "tvOS", "visionOS"]';
    assert.deepEqual([buildPlatforms('nightly-checks.yml'), buildPlatforms('release-sdk.yml')], [all, all]);
  });

  it('come from the one input that the build matrix and both check run steps read', () => {
    assert.match(shared, /^ {8}platform: \$\{\{ fromJSON\(inputs\.build_platforms\) \}\}$/m);
    assert.equal(shared.match(/^ {10}BUILD_PLATFORMS: \$\{\{ inputs\.build_platforms \}\}$/gm)?.length, 2);
  });
});

describe('the Manual CI check runs of the shared checks', () => {
  const tests = { 'Check formatting and linting': 'success', 'Run ClerkKit tests on macOS': 'success', 'Run ClerkKitUI tests on iOS': 'success', 'Run E2E runner tests': 'success' };

  it('are made for each job that a pull request runs, and each one completes with the result of its job', () => {
    assert.deepEqual(checkRuns(buildPlatforms('run-pr-ci.yml'), { ...tests, 'Build iOS': 'success', 'Build macOS': 'failure' }), {
      'Manual CI / Check formatting and linting': 'success',
      'Manual CI / Run ClerkKit tests on macOS': 'success',
      'Manual CI / Run ClerkKitUI tests on iOS': 'success',
      'Manual CI / Run E2E runner tests': 'success',
      'Manual CI / Build iOS': 'success',
      'Manual CI / Build macOS': 'failure',
    });
  });

  it('are made for each build of a release, and each one completes with the result of its job', () => {
    const builds = { 'Build iOS': 'success', 'Build macOS': 'success', 'Build macCatalyst': 'success', 'Build watchOS': 'failure', 'Build tvOS': 'success', 'Build visionOS': 'cancelled' };
    assert.deepEqual(checkRuns(buildPlatforms('release-sdk.yml'), { ...tests, ...builds }), {
      'Manual CI / Check formatting and linting': 'success',
      'Manual CI / Run ClerkKit tests on macOS': 'success',
      'Manual CI / Run ClerkKitUI tests on iOS': 'success',
      'Manual CI / Run E2E runner tests': 'success',
      'Manual CI / Build iOS': 'success',
      'Manual CI / Build macOS': 'success',
      'Manual CI / Build macCatalyst': 'success',
      'Manual CI / Build watchOS': 'failure',
      'Manual CI / Build tvOS': 'success',
      'Manual CI / Build visionOS': 'cancelled',
    });
  });
});

describe('the nightly checks', () => {
  const nightly = read('nightly-checks.yml');
  const job = (name: string): string => nightly.split(/\n(?= {2}[\w-]+:\n)/).find((text) => text.startsWith(`  ${name}:\n`)) ?? '';

  function runs(name: string, context: { event: string; repository?: string; failed?: boolean }): boolean {
    const condition = /^ {4}if: (.+)$/m.exec(job(name))?.[1] ?? 'true';
    const expression = condition
      .replaceAll('failure()', String(context.failed ?? false))
      .replaceAll('github.event_name', JSON.stringify(context.event))
      .replaceAll('github.repository', JSON.stringify(context.repository ?? 'clerk/clerk-ios'))
      .replaceAll(' != ', ' !== ')
      .replaceAll(' == ', ' === ');
    return new Function(`return ${expression};`)() as boolean;
  }

  function notified(webhook: string): { status: number | null; stdout: string; posted: unknown } {
    const work = mkdtempSync(join(tmpdir(), 'nightly-notify-'));
    mkdirSync(join(work, 'bin'));
    writeFileSync(join(work, 'bin', 'curl'), `#!/bin/sh\nwhile [ "$#" -gt 1 ]; do [ "$1" = --data ] && printf '%s' "$2" > "${work}/posted"; shift; done\necho "$1" > "${work}/url"\n`, { mode: 0o755 });
    const ran = spawnSync('bash', ['-c', script('Notify Slack', nightly)], {
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

  it('run every night at 07:00 UTC', () => {
    assert.match(nightly, /^on:\n {2}schedule:\n {4}- cron: "0 7 \* \* \*"$/m);
  });

  it('run on the schedule only in clerk/clerk-ios, so that the nightly run of a fork does nothing', () => {
    assert.deepEqual(
      [
        runs('checks', { event: 'schedule' }),
        runs('checks', { event: 'schedule', repository: 'someone/clerk-ios' }),
        runs('checks', { event: 'workflow_dispatch', repository: 'someone/clerk-ios' }),
      ],
      [true, false, true],
    );
  });

  it('post to Slack only when a scheduled run fails', () => {
    assert.deepEqual(
      [runs('notify', { event: 'schedule', failed: true }), runs('notify', { event: 'schedule', failed: false }), runs('notify', { event: 'workflow_dispatch', failed: true })],
      [true, false, false],
    );
  });

  it('post a message that names the repository and links the run', () => {
    assert.deepEqual(notified('https://hooks.slack.test/T/B/x'), {
      status: 0,
      stdout: '',
      posted: {
        url: 'https://hooks.slack.test/T/B/x',
        payload: {
          text: 'The nightly checks failed in clerk/clerk-ios',
          blocks: [
            { type: 'section', text: { type: 'mrkdwn', text: '*The nightly checks failed in clerk/clerk-ios*' } },
            { type: 'context', elements: [{ type: 'mrkdwn', text: '<https://github.com/clerk/clerk-ios/actions/runs/123|View the run>' }] },
          ],
        },
      },
    });
  });

  it('skip the Slack message with a warning when the repository has no webhook', () => {
    assert.deepEqual(notified(''), { status: 0, stdout: '::warning::SLACK_WEBHOOK_URL is not configured; skipping Slack notification\n', posted: null });
  });
});
