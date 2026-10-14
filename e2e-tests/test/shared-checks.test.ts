import '../testing/git-env.ts';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, it } from 'node:test';

const WORKFLOWS = join(import.meta.dirname, '..', '..', '.github', 'workflows');
const read = (file: string): string => readFileSync(join(WORKFLOWS, file), 'utf8');
const shared = read('shared-checks.yml');

function passed(caller: string, input: string): string | undefined {
  const job = read(caller).split(/\n(?= {2}[\w-]+:\n)/).find((block) => block.includes('uses: ./.github/workflows/shared-checks.yml'));
  assert.ok(job, `${caller} calls shared-checks.yml`);
  return new RegExp(`^ {6}${input}: (.+)$`, 'm').exec(job)?.[1];
}

function buildPlatforms(caller: string): string {
  const platforms = passed(caller, 'build_platforms')?.replace(/^'(.*)'$/, '$1');
  const inputs = shared.slice(shared.indexOf('      build_platforms:'), shared.indexOf('    secrets:'));
  return platforms ?? /^ {8}default: '(.+)'$/m.exec(inputs)?.[1] ?? 'no build_platforms input';
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

  function runs(name: string, context: { event: string; repository?: string; checks?: string; stopped?: boolean }): boolean {
    const condition = (/^ {4}if: >-\n((?: {6}.+\n)+)/m.exec(job(name))?.[1] ?? /^ {4}if: (.+)$/m.exec(job(name))?.[1] ?? 'true').replace(/\s+/g, ' ').trim();
    const expression = condition
      .replaceAll('cancelled()', String(context.stopped ?? false))
      .replace(/contains\(needs\.\*\.result, '(\w+)'\)/g, (_, result: string) => String(result === (context.checks ?? 'success')))
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

  it('run every night at 07:17 UTC, off the top of the hour when GitHub may drop scheduled runs', () => {
    assert.match(nightly, /^on:\n {2}schedule:\n {4}- cron: "17 7 \* \* \*"$/m);
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

  it('post to Slack when a scheduled run fails or times out, and not when it passes, a person stops it, or a person started it', () => {
    assert.deepEqual(
      [
        runs('notify', { event: 'schedule', checks: 'failure' }),
        runs('notify', { event: 'schedule', checks: 'cancelled' }),
        runs('notify', { event: 'schedule', checks: 'success' }),
        runs('notify', { event: 'schedule', checks: 'skipped' }),
        runs('notify', { event: 'schedule', checks: 'cancelled', stopped: true }),
        runs('notify', { event: 'workflow_dispatch', checks: 'failure' }),
      ],
      [true, true, false, false, false, false],
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

describe('the nightly checks and the release', () => {
  it('both run the integration tests with the test keys', () => {
    assert.deepEqual(
      ['nightly-checks.yml', 'release-sdk.yml'].map((caller) => passed(caller, 'run_integration_tests')),
      ['true', 'true'],
    );
    assert.match(read('nightly-checks.yml'), /^ {6}CLERK_TEST_KEYS_JSON: \$\{\{ secrets\.CLERK_TEST_KEYS_JSON \}\}$/m);
  });
});

describe('the E2E runner tests', () => {
  const job = shared.slice(shared.indexOf('  e2e-runner-tests:'), shared.indexOf('  report-manual-ci-check-runs:'));
  const watched = (/^ {6}WATCHED: >-\n((?: {8}.+\n)+)/m.exec(job)?.[1] ?? '').split('\n').map((line) => line.trim()).filter(Boolean);
  const git = (cwd: string, ...args: string[]): string => {
    const ran = spawnSync('git', ['-c', 'user.name=Test', '-c', 'user.email=test@example.com', '-c', 'init.defaultBranch=main', ...args], { cwd, encoding: 'utf8' });
    assert.equal(ran.status, 0, ran.stderr);
    return ran.stdout;
  };
  const change = (cwd: string, file: string, text: string): void => {
    mkdirSync(join(cwd, file, '..'), { recursive: true });
    writeFileSync(join(cwd, file), text);
    git(cwd, 'add', '-A');
    git(cwd, 'commit', '-q', '-m', file);
  };

  function ran(base: string, changed: string, stackedOn?: string): string {
    const server = mkdtempSync(join(tmpdir(), 'e2e-runner-tests-'));
    const upstream = join(server, 'clerk', 'clerk-ios.git');
    mkdirSync(upstream, { recursive: true });
    git(upstream, 'init', '-q');
    for (const file of ['Sources/ClerkKit/Clerk.swift', 'e2e-tests/src/cli.ts', '.github/workflows/verify-remote.yml']) change(upstream, file, 'one\n');
    if (stackedOn) {
      git(upstream, 'switch', '-q', '-c', stackedOn);
      change(upstream, changed, 'changed by the parent pull request\n');
      git(upstream, 'switch', '-q', 'main');
    }
    const pr = join(server, 'pr');
    git(server, 'clone', '-q', upstream, pr);
    git(pr, 'switch', '-q', '-c', 'pr', stackedOn ? `origin/${stackedOn}` : 'HEAD');
    change(pr, changed, stackedOn ? 'one\n' : 'two\n');
    change(upstream, 'e2e-tests/src/cli.ts', 'changed on main after the pull request branched\n');
    writeFileSync(join(server, 'output'), '');
    const checked = spawnSync('bash', ['-c', script('Check whether a file the tests read changed')], {
      cwd: pr,
      env: { PATH: process.env.PATH, BASE: base, WATCHED: watched.join(' '), GITHUB_OUTPUT: join(server, 'output'), GITHUB_SERVER_URL: server, GITHUB_REPOSITORY: 'clerk/clerk-ios' },
      encoding: 'utf8',
      timeout: 20_000,
    });
    assert.equal(checked.status, 0, checked.stderr);
    const output = readFileSync(join(server, 'output'), 'utf8');
    rmSync(server, { recursive: true, force: true });
    return output;
  }

  it('skip on a pull request that changes no file they read, even when main changed one since the pull request branched', () => {
    assert.equal(ran('main', 'Sources/ClerkKit/Clerk.swift'), '');
  });

  it('run on a pull request that changes the test package or a workflow they read', () => {
    assert.deepEqual([ran('main', 'e2e-tests/src/cli.ts'), ran('main', '.github/workflows/verify-remote.yml')], ['run=true\n', 'run=true\n']);
  });

  it('run on a stacked pull request that undoes the change of its parent to a file they read, which a diff against main misses', () => {
    assert.deepEqual([ran('mike/parent', 'e2e-tests/src/cli.ts', 'mike/parent'), ran('main', 'e2e-tests/src/cli.ts', 'mike/parent')], ['run=true\n', '']);
  });

  it('run in full when no branch is given to diff against, and only PR CI gives one', () => {
    assert.equal(ran('', 'Sources/ClerkKit/Clerk.swift'), 'run=true\n');
    assert.deepEqual(
      ['run-pr-ci.yml', 'checks.yml', 'nightly-checks.yml', 'release-sdk.yml'].map((caller) => passed(caller, 'e2e_runner_tests_base')),
      ['${{ needs.resolve-pr-ci-request.outputs.base_ref }}', undefined, undefined, undefined],
    );
  });

  it('skip each step after the check, so the job still succeeds', () => {
    const steps = job.split(/\n(?= {6}- name: )/).slice(1);
    const after = steps.slice(steps.findIndex((step) => step.includes('id: changed')) + 1);
    assert.deepEqual(
      after.map((step) => /^ {8}if: (.+)$/m.exec(step)?.[1]),
      after.map(() => "steps.changed.outputs.run == 'true'"),
    );
    assert.equal(after.length, 5);
  });

  it('watch every workflow a test reads, the scripts, and the test package itself', () => {
    const tests = join(import.meta.dirname);
    const named = new Set(readdirSync(tests).flatMap((file) => [...readFileSync(join(tests, file), 'utf8').matchAll(/[\w-]+\.yml/g)].map((match) => match[0])));
    const workflows = [...named].filter((name) => existsSync(join(WORKFLOWS, name))).map((name) => `.github/workflows/${name}`);
    assert.deepEqual(workflows.filter((path) => !watched.includes(path)), []);
    assert.deepEqual(['e2e-tests', '.github/scripts'].filter((path) => !watched.includes(path)), []);
    assert.deepEqual(watched.filter((path) => !existsSync(join(WORKFLOWS, '..', '..', path))), []);
  });
});
