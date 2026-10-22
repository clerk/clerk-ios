import '@clerk/internal-mobile-e2e/testing/git-env';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, globSync, mkdirSync, mkdtempSync, readFileSync, rmSync, statSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, it } from 'node:test';

const WORKFLOWS = join(import.meta.dirname, '..', '..', '.github', 'workflows');
const read = (file: string): string => readFileSync(join(WORKFLOWS, file), 'utf8');
const shared = read('shared-checks.yml');

function passed(caller: string, name: string): string | undefined {
  const job = read(caller).split(/\n(?= {2}[\w-]+:\n)/).find((block) => block.includes('uses: ./.github/workflows/shared-checks.yml'));
  assert.ok(job, `${caller} calls shared-checks.yml`);
  return new RegExp(`^ {6}${name}: (.+)$`, 'm').exec(job)?.[1];
}

function declaredDefault(name: string): string | undefined {
  const declared = shared.slice(shared.search(new RegExp(`^ {6}${name}:$`, 'm'))).split(/\n(?= {6}\w+:\n)/)[0]!;
  return /^ {8}default: (.+)$/m.exec(declared)?.[1];
}

function input(caller: string, name: string): string {
  return passed(caller, name) ?? declaredDefault(name) ?? `no ${name} input`;
}

const buildPlatforms = (caller: string): string => input(caller, 'build_platforms').replace(/^'(.*)'$/, '$1');

function macOSTestTargets(caller: string, failing?: string): string[] {
  const job = shared.slice(shared.indexOf('  test:\n'), shared.indexOf('  test-ui:\n'));
  let failed = false;
  return job
    .split(/\n(?= {6}- name: )/)
    .slice(1)
    .flatMap((step) => {
      const targets = [...step.matchAll(/\bmake ([\w-]+)/g)].map((match) => match[1]!);
      if (targets.length === 0) return [];
      const written = (/^ {8}if: (.+)$/m.exec(step)?.[1] ?? 'true').replace(/^\$\{\{ (.+) \}\}$/, '$1');
      const condition = (/\b(?:always|success|cancelled)\(\)/.test(written) ? written : `success() && (${written})`)
        .replaceAll('always()', 'true')
        .replaceAll('cancelled()', 'false')
        .replaceAll('success()', String(!failed))
        .replace(/inputs\.(\w+)/g, (_, name: string) => input(caller, name));
      if (!(new Function(`return ${condition};`)() as boolean)) return [];
      failed ||= targets.includes(failing ?? '');
      return targets;
    });
}

function script(step: string, workflow = shared): string {
  const lines = workflow.split('\n');
  const named = lines.findIndex((line) => line.trim() === `- name: ${step}`);
  assert.notEqual(named, -1, `no step ${step}`);
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

describe('the jobs of the shared checks', () => {
  const waitsFor = Object.fromEntries(
    shared
      .slice(shared.indexOf('\njobs:\n'))
      .split(/\n(?= {2}[\w-]+:\n)/)
      .slice(1)
      .map((job) => {
        const block = /^ {4}needs:(?: (.+)$|\n((?: +- [\w-]+\n?)+))/m.exec(job);
        assert.equal(block === null, !/^ {4}needs:/m.test(job), `the needs of this job are a scalar or a list of job names:\n${job}`);
        const needs = block?.[1] !== undefined ? block[1].replace(/^\[(.*)\]$/, '$1').split(',') : (block?.[2] ?? '').split('\n');
        return [/^ {2}([\w-]+):/.exec(job)![1]!, needs.map((need) => need.replace(/^\s*- /, '').trim()).filter(Boolean)];
      }),
  );

  it('all start when the run starts, so the builds and tests wait neither for linting nor for each other', () => {
    assert.deepEqual(waitsFor, {
      'prepare-manual-ci-check-runs': [],
      'format-and-lint': [],
      test: [],
      'test-ui': [],
      build: [],
      'e2e-runner-tests': [],
      'report-manual-ci-check-runs': ['prepare-manual-ci-check-runs', 'format-and-lint', 'test', 'test-ui', 'build', 'e2e-runner-tests'],
    });
  });
});

describe('the runners of the macOS jobs', () => {
  it("are GitHub's free macOS runners in every workflow, but the remote session, which runs on the label its request names", () => {
    const runners = globSync('*.yml', { cwd: WORKFLOWS })
      .sort()
      .flatMap((file) => {
        const workflow = read(file);
        return workflow
          .slice(workflow.indexOf('\njobs:\n'))
          .split(/\n(?= {2}[\w-]+:\n)/)
          .slice(1)
          .flatMap((job): [string, string][] => {
            const id = `${file} ${/^ {2}([\w-]+):/.exec(job)![1]}`;
            if (/^ {4}uses: \.\/\.github\/workflows\/shared-checks\.yml$/m.test(job)) return [[id, input(file, 'macos_runner')]];
            const runsOn = /^ {4}runs-on: (.+)$/m.exec(job)?.[1];
            if (runsOn === undefined || runsOn === '${{ needs.plan.outputs.runner }}') return [];
            const label = (runsOn === '${{ inputs.macos_runner }}' ? declaredDefault('macos_runner') : /^\$\{\{ vars\.VERIFY_CI_RUNNER \|\| '([\w-]+)' \}\}$/.exec(runsOn)?.[1]) ?? runsOn;
            return label.includes('ubuntu') ? [] : [[id, label]];
          });
      });

    assert.deepEqual(Object.fromEntries(runners), {
      'checks.yml checks': 'macos-26',
      'docs.yml deploy': 'macos-26',
      'nightly-checks.yml checks': 'macos-26',
      'release-sdk.yml checks': 'macos-26',
      'release-sdk.yml publish': 'macos-26',
      'run-pr-ci.yml pr-checks': 'macos-26',
      'shared-checks.yml format-and-lint': 'macos-26',
      'shared-checks.yml test': 'macos-26',
      'shared-checks.yml test-ui': 'macos-26',
      'shared-checks.yml build': 'macos-26',
      'verify-app-cache.yml store': 'xcode-27',
      'verify-e2e.yml e2e-tests': 'xcode-27',
    });
  });

  it('are named by no Blacksmith label anywhere, the ubuntu jobs included', () => {
    assert.deepEqual(globSync('*.yml', { cwd: WORKFLOWS }).filter((file) => read(file).includes('blacksmith')), []);
  });
});

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

describe('the ClerkKit tests on macOS', () => {
  it('run the unit tests alone for a pull request and a push to main, and add the integration tests and the macOS smoke build each night and for a release', () => {
    assert.deepEqual(
      ['run-pr-ci.yml', 'checks.yml', 'nightly-checks.yml', 'release-sdk.yml'].map((caller) => macOSTestTargets(caller)),
      [['test'], ['test'], ['test', 'test-integration', 'smoke-macos'], ['test', 'test-integration', 'smoke-macos']],
    );
  });

  it('run both the integration tests and the macOS smoke build each night when one of them fails, so one failure does not hide the other', () => {
    assert.deepEqual(
      [macOSTestTargets('nightly-checks.yml', 'test-integration'), macOSTestTargets('nightly-checks.yml', 'smoke-macos')],
      [['test', 'test-integration', 'smoke-macos'], ['test', 'test-integration', 'smoke-macos']],
    );
  });
});

describe('the Manual CI check runs of the shared checks', () => {
  const tests = { 'Lint': 'success', 'ClerkKit tests (macOS)': 'success', 'ClerkKitUI tests (iOS)': 'success', 'E2E runner tests': 'success' };

  it('are made for each job that a pull request runs, and each one completes with the result of its job', () => {
    assert.deepEqual(checkRuns(buildPlatforms('run-pr-ci.yml'), { ...tests, 'Build iOS': 'success', 'Build macOS': 'failure' }), {
      'Lint': 'success',
      'ClerkKit tests (macOS)': 'success',
      'ClerkKitUI tests (iOS)': 'success',
      'E2E runner tests': 'success',
      'Build iOS': 'success',
      'Build macOS': 'failure',
    });
  });

  it('are made for each build of a release, and each one completes with the result of its job', () => {
    const builds = { 'Build iOS': 'success', 'Build macOS': 'success', 'Build macCatalyst': 'success', 'Build watchOS': 'failure', 'Build tvOS': 'success', 'Build visionOS': 'cancelled' };
    assert.deepEqual(checkRuns(buildPlatforms('release-sdk.yml'), { ...tests, ...builds }), {
      'Lint': 'success',
      'ClerkKit tests (macOS)': 'success',
      'ClerkKitUI tests (iOS)': 'success',
      'E2E runner tests': 'success',
      'Build iOS': 'success',
      'Build macOS': 'success',
      'Build macCatalyst': 'success',
      'Build watchOS': 'failure',
      'Build tvOS': 'success',
      'Build visionOS': 'cancelled',
    });
  });
});

describe('the nightly checks', () => {
  const nightly = read('nightly-checks.yml');
  const job = (name: string): string => nightly.split(/\n(?= {2}[\w-]+:\n)/).find((text) => text.startsWith(`  ${name}:\n`)) ?? '';

  function runs(name: string, context: { event: string; repository?: string; checks?: string; stopped?: boolean }): boolean {
    const written = (/^ {4}if: >-\n((?: {6}.+\n)+)/m.exec(job(name))?.[1] ?? /^ {4}if: (.+)$/m.exec(job(name))?.[1] ?? 'true').replace(/\s+/g, ' ').trim();
    const condition = /\b(?:always|success|failure|cancelled)\(\)/.test(written) ? written : `success() && (${written})`;
    const expression = condition
      .replaceAll('always()', 'true')
      .replaceAll('success()', String((context.checks ?? 'success') === 'success' && !context.stopped))
      .replaceAll('cancelled()', String(context.stopped ?? false))
      .replace(/contains\(needs\.\*\.result, '(\w+)'\)/g, (_, result: string) => String(result === (context.checks ?? 'success')))
      .replaceAll('github.event_name', JSON.stringify(context.event))
      .replaceAll('github.repository', JSON.stringify(context.repository ?? 'clerk/clerk-ios'))
      .replaceAll(' != ', ' !== ')
      .replaceAll(' == ', ' === ');
    return new Function(`return ${expression};`)() as boolean;
  }

  const RELEASE_JOB = 'Push, tag, and publish release';
  const NODE_ARGS = ['.github/scripts/nightly-failure-message.mjs', 'nightly-checks.yml', `release-sdk.yml=${RELEASE_JOB}`];
  const SINCE = 'Merged since the <https://github.com/clerk/clerk-ios/actions/runs/41|last passing run> (2026-10-13 07:17 UTC):\n• <https://github.com/clerk/clerk-ios/pull/705|#705 Add passkeys> · mikepitre';
  const HEADLINE = ':red_circle: clerk/clerk-ios nightly checks failed · <https://github.com/clerk/clerk-ios/actions/runs/123|View the run>';

  function notified(webhook: string, list: 'lists' | 'fails' = 'lists'): { status: number | null; stdout: string; node: string[]; posted: unknown } {
    const work = mkdtempSync(join(tmpdir(), 'nightly-notify-'));
    mkdirSync(join(work, 'bin'));
    writeFileSync(join(work, 'bin', 'curl'), `#!/bin/sh\nwhile [ "$#" -gt 1 ]; do [ "$1" = --data ] && printf '%s' "$2" > "${work}/posted"; shift; done\necho "$1" > "${work}/url"\n`, { mode: 0o755 });
    const node = list === 'lists' ? `printf '%s\\n' '${SINCE}'` : `echo 'GET /actions/workflows/nightly-checks.yml/runs answered 403' >&2; exit 1`;
    writeFileSync(join(work, 'bin', 'node'), `#!/bin/sh\nprintf '%s\\n' "$@" > "${work}/node"\n${node}\n`, { mode: 0o755 });
    const ran = spawnSync('bash', ['-c', script('Notify Slack', nightly)], {
      env: { PATH: `${join(work, 'bin')}:${process.env.PATH}`, SLACK_MOBILE_TEAM_ALERTS_WEBHOOK_URL: webhook, GITHUB_SERVER_URL: 'https://github.com', GITHUB_REPOSITORY: 'clerk/clerk-ios', GITHUB_RUN_ID: '123' },
      encoding: 'utf8',
      timeout: 20_000,
    });
    let posted: unknown = null;
    try {
      posted = { url: readFileSync(join(work, 'url'), 'utf8').trim(), payload: JSON.parse(readFileSync(join(work, 'posted'), 'utf8')) };
    } catch {}
    let args: string[] = [];
    try {
      args = readFileSync(join(work, 'node'), 'utf8').split('\n').slice(0, -1);
    } catch {}
    rmSync(work, { recursive: true, force: true });
    return { status: ran.status, stdout: ran.stdout, node: args, posted };
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

  it('post to Slack when a scheduled run fails, times out or is cancelled, and not when it passes or a person started it', () => {
    assert.deepEqual(
      [
        runs('notify', { event: 'schedule', checks: 'failure' }),
        runs('notify', { event: 'schedule', checks: 'cancelled' }),
        runs('notify', { event: 'schedule', checks: 'cancelled', stopped: true }),
        runs('notify', { event: 'schedule', checks: 'success' }),
        runs('notify', { event: 'schedule', checks: 'skipped' }),
        runs('notify', { event: 'workflow_dispatch', checks: 'failure' }),
      ],
      [true, true, true, false, false, false],
    );
  });

  it('post a message that names the repository, links the run, and lists the pull requests merged since the last passing run, as the nightly end-to-end alert does', () => {
    assert.deepEqual(notified('https://hooks.slack.test/T/B/x'), {
      status: 0,
      stdout: '',
      node: NODE_ARGS,
      posted: { url: 'https://hooks.slack.test/T/B/x', payload: { text: `${HEADLINE}\n${SINCE}`, unfurl_links: false, unfurl_media: false } },
    });
  });

  it('still name the repository and link the run when the list of pull requests cannot be made', () => {
    assert.deepEqual(notified('https://hooks.slack.test/T/B/x', 'fails'), {
      status: 0,
      stdout: '::warning::Could not list the pull requests merged since the last passing run; the message has only its first line\n',
      node: NODE_ARGS,
      posted: { url: 'https://hooks.slack.test/T/B/x', payload: { text: HEADLINE, unfurl_links: false, unfurl_media: false } },
    });
  });

  it('post even when the checkout of the script fails, and read the runs and pull requests with only read access', () => {
    const notify = job('notify');
    const post = notify.split(/\n(?= {6}- name: )/).find((step) => step.includes('- name: Notify Slack')) ?? '';
    const granted = (/^ {4}permissions:\n((?: {6}[\w-]+: \w+\n)+)/m.exec(notify)?.[1] ?? '').trim().split('\n').map((line) => line.trim());
    assert.deepEqual(
      { post: /^ {8}if: (.+)$/m.exec(post)?.[1], token: /^ {10}GITHUB_TOKEN: (.+)$/m.exec(post)?.[1], permissions: granted },
      { post: 'always()', token: '${{ github.token }}', permissions: ['actions: read', 'contents: read', 'pull-requests: read'] },
    );
  });

  it('count a release as the last passing run only when it published, which it does only after its shared checks passed', () => {
    const release = read('release-sdk.yml').split(/\n(?= {2}[\w-]+:\n)/).find((text) => text.startsWith('  publish:\n')) ?? '';
    assert.equal(/^ {4}name: (.+)$/m.exec(release)?.[1], RELEASE_JOB);
    assert.match(release, /^ {4}if: .*\bneeds\.checks\.result == 'success'/m);
  });

  it('skip the Slack message with a warning when the repository has no webhook', () => {
    assert.deepEqual(notified(''), { status: 0, stdout: '::warning::SLACK_MOBILE_TEAM_ALERTS_WEBHOOK_URL is not configured; skipping Slack notification\n', node: [], posted: null });
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

describe('the alert about a blocked release', () => {
  const release = read('release-sdk.yml');
  const jobs = release.slice(release.indexOf('\njobs:\n')).split(/\n(?= {2}[\w-]+:\n)/).slice(1);
  const alert = jobs.find((text) => text.startsWith('  notify-blocked-release:\n')) ?? '';
  const RUN = '<https://github.com/clerk/clerk-ios/actions/runs/123|View the run>';

  function posts(needs: Readonly<Record<string, string>>, stopped = false): boolean {
    const written = (/^ {4}if: >-\n((?: {6}.+\n)+)/m.exec(alert)?.[1] ?? /^ {4}if: (.+)$/m.exec(alert)?.[1] ?? 'true').replace(/\s+/g, ' ').trim();
    const results = Object.values(needs);
    const expression = (/\b(?:always|success|failure|cancelled)\(\)/.test(written) ? written : `success() && (${written})`)
      .replaceAll('always()', 'true')
      .replaceAll('success()', String(!stopped && results.every((result) => result === 'success')))
      .replaceAll('failure()', String(results.includes('failure')))
      .replaceAll('cancelled()', String(stopped))
      .replace(/contains\(needs\.\*\.result, '(\w+)'\)/g, (_, result: string) => String(results.includes(result)))
      .replace(/needs\.([\w-]+)\.result/g, (_, job: string) => JSON.stringify(needs[job] ?? ''))
      .replaceAll("'", '"')
      .replaceAll(' != ', ' !== ')
      .replaceAll(' == ', ' === ');
    return new Function(`return ${expression};`)() as boolean;
  }

  function notified(webhook: string, needs: Readonly<Record<string, string>>, withScript = true): { status: number | null; stdout: string; posted: unknown } {
    const work = mkdtempSync(join(tmpdir(), 'release-blocked-'));
    mkdirSync(join(work, 'bin'));
    mkdirSync(join(work, '.github', 'scripts'), { recursive: true });
    if (withScript) writeFileSync(join(work, '.github', 'scripts', 'nightly-failure-message.mjs'), readFileSync(join(WORKFLOWS, '..', 'scripts', 'nightly-failure-message.mjs')));
    writeFileSync(join(work, 'bin', 'curl'), `#!/bin/sh\nwhile [ "$#" -gt 1 ]; do [ "$1" = --data ] && printf '%s' "$2" > "${work}/posted"; shift; done\necho "$1" > "${work}/url"\n`, { mode: 0o755 });
    const ran = spawnSync('bash', ['-c', script('Notify Slack', release)], {
      cwd: work,
      env: {
        PATH: `${join(work, 'bin')}:${process.env.PATH}`,
        SLACK_MOBILE_TEAM_ALERTS_WEBHOOK_URL: webhook,
        RELEASE_VERSION: '1.2.3',
        NEEDS: JSON.stringify(Object.fromEntries(Object.entries(needs).map(([job, result]) => [job, { result, outputs: {} }])), null, 2),
        GITHUB_SERVER_URL: 'https://github.com',
        GITHUB_REPOSITORY: 'clerk/clerk-ios',
        GITHUB_RUN_ID: '123',
      },
      encoding: 'utf8',
      timeout: 20_000,
    });
    let posted: unknown = null;
    try {
      posted = { url: readFileSync(join(work, 'url'), 'utf8').trim(), text: JSON.parse(readFileSync(join(work, 'posted'), 'utf8')).text };
    } catch {}
    rmSync(work, { recursive: true, force: true });
    return { status: ran.status, stdout: ran.stdout, posted };
  }

  it('post to Slack when a gate fails or is cancelled, and not when the gates pass, when no gate ran, or when a person cancels the run before a gate fails', () => {
    assert.deepEqual(
      [
        posts({ 'start-manual-ci': 'success', checks: 'failure', 'e2e-tests': 'success' }),
        posts({ 'start-manual-ci': 'skipped', checks: 'success', 'e2e-tests': 'failure' }),
        posts({ 'start-manual-ci': 'failure', checks: 'skipped', 'e2e-tests': 'success' }),
        posts({ 'start-manual-ci': 'success', checks: 'cancelled', 'e2e-tests': 'success' }),
        posts({ 'start-manual-ci': 'success', checks: 'failure', 'e2e-tests': 'cancelled' }, true),
        posts({ 'start-manual-ci': 'success', checks: 'success', 'e2e-tests': 'success' }),
        posts({ 'start-manual-ci': 'skipped', checks: 'success', 'e2e-tests': 'success' }),
        posts({ 'start-manual-ci': 'skipped', checks: 'skipped', 'e2e-tests': 'skipped' }),
        posts({ 'start-manual-ci': 'success', checks: 'cancelled', 'e2e-tests': 'cancelled' }, true),
      ],
      [true, true, true, true, true, false, false, false, false],
    );
  });

  it('wait for the gates alone, read only the repository contents, and hold up no job of the release', () => {
    assert.deepEqual(
      {
        needs: (/^ {4}needs:\n((?: {6}- .+\n)+)/m.exec(alert)?.[1] ?? '').trim().split('\n').map((line) => line.trim()),
        permissions: (/^ {4}permissions:\n((?: {6}[\w-]+: \w+\n)+)/m.exec(alert)?.[1] ?? '').trim().split('\n').map((line) => line.trim()),
        waiting: jobs.filter((text) => /^ {4}needs:(?:.|\n {6}- )*\bnotify-blocked-release\b/m.test(text)).length,
      },
      { needs: ['- start-manual-ci', '- checks', '- e2e-tests'], permissions: ['contents: read'], waiting: 0 },
    );
  });

  it('post a message that names the repository, the version and the gates that failed, and links the run', () => {
    assert.deepEqual(notified('https://hooks.slack.test/T/B/x', { 'start-manual-ci': 'success', checks: 'failure', 'e2e-tests': 'failure' }), {
      status: 0,
      stdout: '',
      posted: { url: 'https://hooks.slack.test/T/B/x', text: `:red_circle: clerk/clerk-ios 1.2.3 release blocked: shared checks and end-to-end tests failed · ${RUN}` },
    });
  });

  it('still name the repository and link the run when the script cannot name the release or the gates', () => {
    assert.deepEqual(notified('https://hooks.slack.test/T/B/x', { 'start-manual-ci': 'success', checks: 'failure', 'e2e-tests': 'success' }, false), {
      status: 0,
      stdout: '::warning::Could not name the release or the gates that stopped it; the message names neither\n',
      posted: { url: 'https://hooks.slack.test/T/B/x', text: `:red_circle: clerk/clerk-ios release blocked · ${RUN}` },
    });
  });

  it('skip the Slack message with a warning when the repository has no webhook', () => {
    assert.deepEqual(notified('', { checks: 'failure' }), { status: 0, stdout: '::warning::SLACK_MOBILE_TEAM_ALERTS_WEBHOOK_URL is not configured; skipping Slack notification\n', posted: null });
  });

  it('retry the post as the nightly alert does, since a second message costs less than a lost one', () => {
    const post = (text: string): string => text.slice(text.indexOf('curl '));
    assert.equal(post(script('Notify Slack', release)), post(script('Notify Slack', read('nightly-checks.yml'))));
  });
});

describe('the saved builds of the ClerkKit tests on macOS and the ClerkKitUI tests', () => {
  const jobBlock = (id: string): string => {
    const start = shared.indexOf(`\n  ${id}:\n`) + 1;
    return shared.slice(start, start + 1 + shared.slice(start + 1).search(/^ {2}\S/m));
  };
  const caches = {
    test: { restore: 'Restore the SwiftPM build of the last main push', save: 'Save the SwiftPM build for later runs' },
    'test-ui': { restore: 'Restore the Xcode build of the last main push', save: 'Save the Xcode build for later runs' },
  };

  it('give each tracked file a modification time from its content in both jobs, so a restored build sees only changed files as changed', () => {
    const stamped = (job: string): number[] => {
      const repo = mkdtempSync(join(tmpdir(), 'build-cache-times-'));
      const git = (...args: string[]): void => {
        const ran = spawnSync('git', ['-c', 'user.name=Test', '-c', 'user.email=test@example.com', ...args], { cwd: repo, encoding: 'utf8' });
        assert.equal(ran.status, 0, ran.stderr);
      };
      git('init', '-q');
      mkdirSync(join(repo, 'Sources'));
      writeFileSync(join(repo, 'Sources', 'Same.swift'), 'hello\n');
      writeFileSync(join(repo, 'Sources', 'Changed.swift'), 'world\n');
      symlinkSync('Same.swift', join(repo, 'Sources', 'ZLink.swift'));
      git('add', '-A');
      git('commit', '-q', '-m', 'sources');

      const ran = spawnSync('bash', ['-c', script('Give each file a modification time from its content', jobBlock(job))], { cwd: repo, encoding: 'utf8', timeout: 20_000 });
      assert.equal(ran.status, 0, ran.stderr);
      const seconds = ['Same.swift', 'Changed.swift', 'ZLink.swift'].map((file) => statSync(join(repo, 'Sources', file)).mtimeMs / 1000);
      rmSync(repo, { recursive: true, force: true });
      return seconds;
    };

    assert.deepEqual({ test: stamped('test'), 'test-ui': stamped('test-ui') }, { test: [1162696418, 1160997964, 1162696418], 'test-ui': [1162696418, 1160997964, 1162696418] });
  });

  it('restore a build only in PR CI and save one only from a push to main, so main, the nightly and the release always build from scratch', () => {
    const entryPoints = (file: string): [string, string[]][] => {
      const on = /^on:\n((?: {2}.*\n|\n)*)/m.exec(read(file))?.[1] ?? '';
      const events = [...on.matchAll(/^ {2}([\w-]+):/gm)].map((match) => match[1]!);
      if (!events.includes('workflow_call')) return [[file, events]];
      return globSync('*.yml', { cwd: WORKFLOWS })
        .filter((caller) => read(caller).includes(`uses: ./.github/workflows/${file}`))
        .flatMap(entryPoints);
    };
    const events = (job: keyof typeof caches) => {
      const steps = jobBlock(job).split(/\n(?= {6}- name: )/);
      const step = (name: string): string => steps.find((candidate) => candidate.includes(`- name: ${name}\n`)) ?? assert.fail(`no step ${name} in ${job}`);
      const runsOn = (name: string, event: string): boolean => new Function('github', `return ${/^ {8}if: (.+)$/m.exec(step(name))?.[1] ?? 'true'};`)({ event_name: event }) as boolean;
      const restoreKeys = /^ {10}restore-keys: (.+)$/m.exec(step(caches[job].restore))?.[1];
      assert.equal(/^ {10}key: (.+)$/m.exec(step(caches[job].save))?.[1], `${restoreKeys}\${{ github.sha }}`);
      return Object.fromEntries(
        entryPoints('shared-checks.yml').map(([caller, callerEvents]) => [
          caller,
          { restores: callerEvents.filter((event) => runsOn(caches[job].restore, event)), saves: callerEvents.filter((event) => runsOn(caches[job].save, event)) },
        ]),
      );
    };
    const prCiRestoresMainSaves = {
      'checks.yml': { restores: [], saves: ['push'] },
      'manual-pr-ci.yml': { restores: ['issue_comment', 'pull_request_target'], saves: [] },
      'nightly-checks.yml': { restores: [], saves: [] },
      'release-sdk.yml': { restores: [], saves: [] },
    };

    assert.deepEqual({ test: events('test'), 'test-ui': events('test-ui') }, { test: prCiRestoresMainSaves, 'test-ui': prCiRestoresMainSaves });
  });

  it('keep only the newest build of each job on main once a push saved its own, and delete none of a job whose push saved nothing', () => {
    const sha = 'c'.repeat(40);
    const newer = 'd'.repeat(40);
    const gone = 'e'.repeat(40);
    const ui = 'clerkkitui-derived-data-ARM64-Xcode-26.6-Build-version-17F113-';
    const macOS = 'clerkkit-swiftpm-build-ARM64-Xcode-26.6-Build-version-17F113-';
    const deleted = (saved: string[]): string[] => {
      const work = mkdtempSync(join(tmpdir(), 'build-cache-cleanup-'));
      mkdirSync(join(work, 'bin'));
      writeFileSync(join(work, 'deleted'), '');
      writeFileSync(
        join(work, 'bin', 'gh'),
        `#!/bin/bash
case "$1 $2" in
  'cache list') order=tac; while [ $# -gt 0 ]; do [ "$1" = --key ] && prefix=$2; [ "$1 $2 $3 $4" = '--sort created_at --order desc' ] && order=cat; shift; done; printf '%s\\n' ${saved.map((key) => `'${key}'`).join(' ')} | grep -- "^$prefix" | $order || true ;;
  'cache delete') [[ "$3" == *${gone} ]] && exit 1; echo "$3" >> '${work}/deleted' ;;
  *) exit 1 ;;
esac
`,
        { mode: 0o755 },
      );
      const ran = spawnSync('bash', ['-c', script('Delete the older saved builds', read('checks.yml'))], {
        env: { PATH: `${join(work, 'bin')}:${process.env.PATH}`, GITHUB_REPOSITORY: 'clerk/clerk-ios', GITHUB_REF: 'refs/heads/main', GITHUB_SHA: sha },
        encoding: 'utf8',
        timeout: 20_000,
      });
      assert.equal(ran.status, 0, ran.stderr);
      const keys = readFileSync(join(work, 'deleted'), 'utf8').split('\n').filter(Boolean);
      rmSync(work, { recursive: true, force: true });
      return keys.sort();
    };
    const olderXcode = (prefix: string): string => `${prefix.replace('26.6-Build-version-17F113', '26.0-Build-version-17A324')}${'b'.repeat(40)}`;

    assert.deepEqual(deleted([`${ui}${sha}`, `${ui}${'a'.repeat(40)}`, olderXcode(ui), `${macOS}${sha}`, `${macOS}${'a'.repeat(40)}`, olderXcode(macOS)]), [
      `${ui}${'a'.repeat(40)}`,
      olderXcode(ui),
      `${macOS}${'a'.repeat(40)}`,
      olderXcode(macOS),
    ].sort());
    assert.deepEqual(deleted([`${ui}${sha}`, `${ui}${'a'.repeat(40)}`, `${macOS}${'a'.repeat(40)}`]), [`${ui}${'a'.repeat(40)}`]);
    assert.deepEqual(deleted([`${ui}${'a'.repeat(40)}`, `${macOS}${sha}`, `${macOS}${'a'.repeat(40)}`]), [`${macOS}${'a'.repeat(40)}`]);
    assert.deepEqual(deleted([`${ui}${newer}`, `${ui}${sha}`, `${macOS}${newer}`, `${macOS}${sha}`]), [`${ui}${sha}`, `${macOS}${sha}`].sort());
    assert.deepEqual(deleted([`${ui}${sha}`, `${ui}${gone}`, `${macOS}${sha}`, `${macOS}${'a'.repeat(40)}`]), [`${macOS}${'a'.repeat(40)}`]);
    assert.deepEqual(deleted([`${ui}${sha}`, `${macOS}${sha}`]), []);
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

  it('watch every workflow and repository file that a test of the job reads, the scripts, and the test package itself', () => {
    const pkg = join(import.meta.dirname, '..');
    const root = join(pkg, '..');
    const commands = [JSON.parse(readFileSync(join(pkg, 'package.json'), 'utf8')).scripts.test as string, ...[...job.matchAll(/^ {8}run: (node --test .+)$/gm)].map((match) => match[1]!)];
    const tests = commands.flatMap((command) => command.split(' ').slice(2)).flatMap((pattern) => globSync(pattern, { cwd: pkg }).map((file) => join(pkg, file)));
    assert.ok(tests.some((file) => file.endsWith('.github/scripts/verify-attach.test.mjs')) && tests.some((file) => file.endsWith('shared-checks.test.ts')), tests.join(', '));
    const onlyInThrowawayRepos = ['Clerk.xcworkspace/contents.xcworkspacedata', 'Examples/E2EHost/E2EHost/E2EHostApp.swift', 'Examples/Quickstart/Quickstart/ContentView.swift'];
    const reads = new Set(
      tests.flatMap((file) => {
        const text = readFileSync(file, 'utf8');
        const workflows = [...text.matchAll(/[\w-]+\.yml/g)].map((match) => `.github/workflows/${match[0]}`);
        const paths = [...text.matchAll(/['"`]([\w.-]+(?:\/[\w.-]+)+)['"`]/g)].map((match) => match[1]!);
        return [...workflows, ...paths].filter((path) => existsSync(join(root, path)) && !onlyInThrowawayRepos.includes(path));
      }),
    );
    assert.deepEqual([...reads].filter((path) => !watched.some((entry) => path === entry || path.startsWith(`${entry}/`))), []);
    assert.deepEqual(['e2e-tests', '.github/scripts'].filter((path) => !watched.includes(path)), []);
    assert.deepEqual(watched.filter((path) => !existsSync(join(root, path))), []);
  });
});
