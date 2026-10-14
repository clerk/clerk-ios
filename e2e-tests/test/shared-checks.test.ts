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

function script(step: string): string {
  const lines = shared.split('\n');
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
  it('are iOS and macOS for a pull request', () => {
    assert.equal(buildPlatforms('run-pr-ci.yml'), '["iOS", "macOS"]');
  });

  it('are all six for a release, so a break on macCatalyst, watchOS, tvOS or visionOS stops the release', () => {
    assert.equal(buildPlatforms('release-sdk.yml'), '["iOS", "macOS", "macCatalyst", "watchOS", "tvOS", "visionOS"]');
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
