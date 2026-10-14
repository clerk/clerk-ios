import '../testing/git-env.ts';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { cpSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { after, describe, it } from 'node:test';
import { BUILD_INPUTS } from '../src/host-app.ts';
import { stageLine } from '../src/platform/ios/session-build.ts';
import { appKey, pathsOutsideInputs } from '../src/platform/ios/stored-app.ts';

const PACKAGE_DIR = join(import.meta.dirname, '..');
const SESSION_BUILD = join(PACKAGE_DIR, 'src', 'platform', 'ios', 'session-build.ts');
const WORKFLOWS = join(PACKAGE_DIR, '..', '.github', 'workflows');
const AUTHOR = ['-c', 'user.name=t', '-c', 'user.email=t@example.com'];
const SOURCE = 'Sources/ClerkKit/Clerk.swift';
const HOST_APP = 'Examples/E2EHost/E2EHost/E2EHostApp.swift';
const PROJECT = 'Examples/Quickstart/Quickstart.xcodeproj/project.pbxproj';

const XCODEBUILD = `#!/bin/sh
echo "xcodebuild $*" >> "$FAKE/calls"
case "$1" in
  -version) printf 'Xcode 27.0\\nBuild version %s\\n' "$(cat "$FAKE/xcode")" ;;
  -resolvePackageDependencies)
    mkdir -p Clerk.xcworkspace/xcshareddata/swiftpm
    printf '{"pins":[{"identity":"nuke","kind":"remoteSourceControl","location":"https://github.com/kean/Nuke","state":{"revision":"%s","version":"13.0.6"}}],"version":3}' "$(cat "$FAKE/pins")" > Clerk.xcworkspace/xcshareddata/swiftpm/Package.resolved ;;
  build)
    [ -f "$FAKE/fail" ] && { echo "error: no such module"; exit 65; }
    for arg; do [ "$previous" = -derivedDataPath ] && derived=$arg; previous=$arg; done
    app="$derived/Build/Products/Debug-iphonesimulator/E2EHost.app"
    data="$derived/Build/Intermediates.noindex/XCBuildData/1.xcbuilddata"
    mkdir -p "$app" "$data"
    echo plist > "$app/Info.plist"
    cat ${SOURCE} ${HOST_APP} > "$app/E2EHost"
    printf '{"commands":{"c":{"inputs":["%s/${SOURCE}","%s/Examples/Quickstart/","%s","%s/%s","/Applications/Xcode.app/usr/bin/swiftc"]}}}' "$PWD" "$PWD" "$PWD" "$PWD" "$(cat "$FAKE/also-reads")" > "$data/manifest.json"
    [ -f "$FAKE/pins-after" ] && cp "$FAKE/pins-after" "$FAKE/pins" && "$0" -resolvePackageDependencies
    exit 0 ;;
esac
`;

const XCRUN = `#!/bin/sh
echo "xcrun $*" >> "$FAKE/calls"
case "$*" in
  *--show-sdk-build-version) cat "$FAKE/sdk" ;;
  *"simctl install"*) cat "$4/E2EHost" > "$FAKE/installed" ;;
esac
`;

interface Checkout {
  readonly dir: string;
  readonly fake: string;
  readonly env: NodeJS.ProcessEnv;
}

const made: string[] = [];
after(() => made.forEach((dir) => rmSync(dir, { recursive: true, force: true })));

function scratch(prefix: string): string {
  const dir = mkdtempSync(join(tmpdir(), prefix));
  made.push(dir);
  return dir;
}

function commit(checkout: Checkout, file: string, text: string): void {
  mkdirSync(dirname(join(checkout.dir, file)), { recursive: true });
  writeFileSync(join(checkout.dir, file), text);
  execFileSync('git', ['add', '-A'], { cwd: checkout.dir });
  execFileSync('git', [...AUTHOR, 'commit', '-q', '-m', file], { cwd: checkout.dir });
}

function checkout(): Checkout {
  const dir = scratch('verify-stored-app-');
  const fake = scratch('verify-stored-app-fake-');
  mkdirSync(join(fake, 'bin'));
  writeFileSync(join(fake, 'bin', 'xcodebuild'), XCODEBUILD, { mode: 0o755 });
  writeFileSync(join(fake, 'bin', 'xcrun'), XCRUN, { mode: 0o755 });
  for (const [name, value] of Object.entries({ xcode: '27A266a', sdk: '25A300', pins: 'aaaa', 'also-reads': SOURCE, calls: '' })) writeFileSync(join(fake, name), value);
  const made: Checkout = { dir, fake, env: { PATH: `${join(fake, 'bin')}:${process.env.PATH}`, FAKE: fake, HOME: fake } };
  execFileSync('git', ['init', '-q'], { cwd: dir });
  const files = { '.gitignore': 'Package.resolved\n', [SOURCE]: 'sdk one\n', [HOST_APP]: 'host one\n', [PROJECT]: 'project one\n', 'Package.swift': 'package one\n', 'Clerk.xcworkspace/contents.xcworkspacedata': 'workspace\n', 'README.md': 'readme\n', 'e2e-tests/specs/golden/a.e2e.ts': 'spec\n' };
  for (const [file, text] of Object.entries(files)) {
    mkdirSync(dirname(join(dir, file)), { recursive: true });
    writeFileSync(join(dir, file), text);
  }
  execFileSync('git', ['add', '-A'], { cwd: dir });
  execFileSync('git', [...AUTHOR, 'commit', '-q', '-m', 'first'], { cwd: dir });
  return made;
}

function sessionBuild(from: Checkout, args: readonly string[]): { readonly status: number | null; readonly stdout: string } {
  const ran = spawnSync(process.execPath, [SESSION_BUILD, ...args], { cwd: from.dir, env: from.env, encoding: 'utf8', timeout: 60_000 });
  return { status: ran.status, stdout: ran.stdout + ran.stderr };
}

function named(from: Checkout): Readonly<Record<string, string>> {
  const { stdout } = sessionBuild(from, ['name', scratch('verify-stored-app-work-')]);
  return Object.fromEntries(stdout.split('\n').filter((line) => /^\w+=/.test(line)).map((line) => line.split('=') as [string, string]));
}

const callsOf = (from: Checkout): readonly string[] => readFileSync(join(from.fake, 'calls'), 'utf8').split('\n').filter((line) => line !== '');
const builds = (from: Checkout): number => callsOf(from).filter((line) => line.startsWith('xcodebuild build ')).length;
const installed = (from: Checkout): string => readFileSync(join(from.fake, 'installed'), 'utf8');
const outcomeOf = (work: string): { state: string; key: string | null; storable: boolean; why: string } => JSON.parse(readFileSync(join(work, 'app.json'), 'utf8'));

function carriedTo(work: string): string {
  const next = scratch('verify-stored-app-work-');
  cpSync(join(work, 'apps'), join(next, 'apps'), { recursive: true });
  return next;
}

describe('the key of a stored E2EHost', () => {
  it('is 32 hex digits made from the sources, the packages, Xcode, the SDK, the processor and the build command', () => {
    const identity = { inputs: 'a', pins: 'b', xcode: '27A266a', sdk: '25A300', arch: 'arm64', command: 'build -quiet' };
    assert.equal(appKey(identity), 'f1a099607eaff57479b9398c783e7ae3');
    for (const field of Object.keys(identity) as (keyof typeof identity)[]) assert.notEqual(appKey({ ...identity, [field]: 'other' }), appKey(identity), field);
  });

  it('changes with a Swift source, the host app, the project, Package.swift, a package version, Xcode and the SDK', () => {
    const repo = checkout();
    const first = named(repo).key!;
    assert.match(first, /^[0-9a-f]{32}$/);
    const changes: Readonly<Record<string, () => void>> = {
      'a Swift source under Sources': () => commit(repo, SOURCE, 'sdk two\n'),
      'a new Swift source under Sources': () => commit(repo, 'Sources/ClerkKitUI/New.swift', 'new\n'),
      'the host app': () => commit(repo, HOST_APP, 'host two\n'),
      'the Xcode project': () => commit(repo, PROJECT, 'project two\n'),
      'Package.swift': () => commit(repo, 'Package.swift', 'package two\n'),
      'the revision a package resolves to': () => writeFileSync(join(repo.fake, 'pins'), 'bbbb'),
      'the Xcode build': () => writeFileSync(join(repo.fake, 'xcode'), '27B100'),
      'the simulator SDK': () => writeFileSync(join(repo.fake, 'sdk'), '25B200'),
    };
    const seen = [first];
    for (const [what, change] of Object.entries(changes)) {
      change();
      const key = named(repo).key!;
      assert.match(key, /^[0-9a-f]{32}$/, what);
      assert.ok(!seen.includes(key), `${what} gave a key seen before`);
      seen.push(key);
    }
  });

  it('stays the same when only a spec, a doc or a workflow changes', () => {
    const repo = checkout();
    const first = named(repo).key;
    commit(repo, 'e2e-tests/specs/golden/a.e2e.ts', 'spec two\n');
    commit(repo, 'README.md', 'readme two\n');
    commit(repo, 'docs/guide.md', 'guide\n');
    commit(repo, '.github/workflows/checks.yml', 'on: push\n');
    assert.equal(named(repo).key, first);
  });

  it('is empty, with the reason, when the app sources differ from the commit', () => {
    const repo = checkout();
    writeFileSync(join(repo.dir, SOURCE), 'not committed\n');
    const { stdout } = sessionBuild(repo, ['name', scratch('verify-stored-app-work-')]);
    assert.match(stdout, /^::warning title=verify::no stored app is used or kept: the checkout differs from [0-9a-f]{12} in Sources\/ClerkKit\/Clerk\.swift$/m);
    assert.match(stdout, /^key=$/m);
  });
});

describe('a session build', () => {
  it('builds an app that is not stored, installs it, and stores it under its key', () => {
    const repo = checkout();
    const work = scratch('verify-stored-app-work-');
    const { key } = named(repo);
    assert.equal(sessionBuild(repo, ['build', work, 'UDID-1']).status, 0);
    assert.equal(builds(repo), 1);
    assert.equal(installed(repo), 'sdk one\nhost one\n');
    assert.deepEqual(outcomeOf(work), { state: 'built', key, storable: true, why: 'stored for the next session with the same sources, packages and Xcode' });
    assert.deepEqual(readdirSync(join(work, 'apps')), [key]);
    const steps = callsOf(repo).filter((line) => line.startsWith('xcodebuild build') || line.startsWith('xcrun simctl')).map((line) => line.split(' ').slice(0, 3).join(' '));
    assert.deepEqual(steps, ['xcodebuild build -quiet', 'xcrun simctl bootstatus', 'xcrun simctl install'], 'the simulator boots after the build');
  });

  it('installs the stored app without a build when the key is the same', () => {
    const repo = checkout();
    const first = scratch('verify-stored-app-work-');
    sessionBuild(repo, ['build', first, 'UDID-1']);
    commit(repo, 'e2e-tests/specs/golden/a.e2e.ts', 'spec two\n');
    rmSync(join(repo.fake, 'installed'));
    const next = carriedTo(first);
    assert.equal(sessionBuild(repo, ['build', next, 'UDID-1']).status, 0);
    assert.equal(builds(repo), 1, 'no second build');
    assert.equal(installed(repo), 'sdk one\nhost one\n');
    assert.equal(outcomeOf(next).state, 'stored');
  });

  it('builds again, and never installs the stored app, after a Swift source changes', () => {
    const repo = checkout();
    const first = scratch('verify-stored-app-work-');
    sessionBuild(repo, ['build', first, 'UDID-1']);
    commit(repo, SOURCE, 'sdk two\n');
    const next = carriedTo(first);
    assert.equal(sessionBuild(repo, ['build', next, 'UDID-1']).status, 0);
    assert.equal(builds(repo), 2);
    assert.equal(installed(repo), 'sdk two\nhost one\n');
    assert.equal(readdirSync(join(next, 'apps')).length, 2);
  });

  it('builds again when the stored app was made with another package revision', () => {
    const repo = checkout();
    const first = scratch('verify-stored-app-work-');
    sessionBuild(repo, ['build', first, 'UDID-1']);
    writeFileSync(join(repo.fake, 'pins'), 'bbbb');
    assert.equal(sessionBuild(repo, ['build', carriedTo(first), 'UDID-1']).status, 0);
    assert.equal(builds(repo), 2);
  });

  it('ignores a stored app whose record does not make its key', () => {
    const repo = checkout();
    const first = scratch('verify-stored-app-work-');
    sessionBuild(repo, ['build', first, 'UDID-1']);
    const key = outcomeOf(first).key!;
    commit(repo, SOURCE, 'sdk two\n');
    const wanted = named(repo).key!;
    const next = scratch('verify-stored-app-work-');
    cpSync(join(first, 'apps', key), join(next, 'apps', wanted), { recursive: true });
    assert.equal(sessionBuild(repo, ['build', next, 'UDID-1']).status, 0);
    assert.equal(builds(repo), 2);
    assert.equal(installed(repo), 'sdk two\nhost one\n');
  });

  it('does not store an app when the build resolved other packages than the key names', () => {
    const repo = checkout();
    const work = scratch('verify-stored-app-work-');
    writeFileSync(join(repo.fake, 'pins-after'), 'cccc');
    assert.equal(sessionBuild(repo, ['build', work, 'UDID-1']).status, 0);
    assert.equal(installed(repo), 'sdk one\nhost one\n');
    assert.equal(outcomeOf(work).why, 'not stored: the build resolved other package versions than the ones in the key');
    assert.equal(existsSync(join(work, 'apps')), false);
    assert.match(sessionBuild(repo, ['outcome', work]).stdout, /^store=$/m);
  });

  it('does not store an app when the build read a file of the repository that the key does not cover', () => {
    const repo = checkout();
    const work = scratch('verify-stored-app-work-');
    writeFileSync(join(repo.fake, 'also-reads'), 'Tests/Shared/Fixture.swift');
    assert.equal(sessionBuild(repo, ['build', work, 'UDID-1']).status, 0);
    assert.equal(outcomeOf(work).why, 'not stored: the build read files that the key does not cover: Tests/Shared/Fixture.swift');
    assert.equal(existsSync(join(work, 'apps')), false);
  });

  it('boots the simulator and installs nothing when the build fails', () => {
    const repo = checkout();
    const work = scratch('verify-stored-app-work-');
    writeFileSync(join(repo.fake, 'fail'), '');
    assert.equal(sessionBuild(repo, ['build', work, 'UDID-1']).status, 65);
    assert.equal(outcomeOf(work).state, 'failed');
    assert.deepEqual(callsOf(repo).filter((line) => line.startsWith('xcrun simctl')), ['xcrun simctl bootstatus UDID-1 -b']);
    assert.equal(readFileSync(join(work, 'booted'), 'utf8'), '0\n');
  });

  it('gives a source the time of its last build when its content is the same, and a new time when it changed', () => {
    const repo = checkout();
    const work = scratch('verify-stored-app-work-');
    sessionBuild(repo, ['build', work, 'UDID-1']);
    const seconds = (file: string): number => statSync(join(repo.dir, file)).mtimeMs / 1000;
    const built = { source: seconds(SOURCE), host: seconds(HOST_APP) };
    assert.equal(built.source, Math.floor(built.source), 'a whole second, which a restore can set again exactly');
    for (const file of [SOURCE, HOST_APP]) execFileSync('touch', ['-t', '203001010000', join(repo.dir, file)]);
    spawnSync('sleep', ['1.1']);
    commit(repo, HOST_APP, 'host two\n');
    sessionBuild(repo, ['build', work, 'UDID-1']);
    assert.equal(seconds(SOURCE), built.source);
    assert.ok(seconds(HOST_APP) > built.host && seconds(HOST_APP) < built.host + 3600, `${seconds(HOST_APP)} is the time of this build`);
  });

  it('reports what to store, and nothing for an app that was already stored', () => {
    const repo = checkout();
    const work = scratch('verify-stored-app-work-');
    sessionBuild(repo, ['build', work, 'UDID-1']);
    const key = outcomeOf(work).key;
    assert.equal(sessionBuild(repo, ['outcome', work]).stdout, `state=built\nstore=${key}\nbuilt=${key}\n`);
    const next = carriedTo(work);
    sessionBuild(repo, ['build', next, 'UDID-1']);
    assert.equal(sessionBuild(repo, ['outcome', next]).stdout, 'state=stored\nstore=\nbuilt=\n');
  });
});

describe('the check of what a build read', () => {
  it('names the paths of the repository that are outside the build inputs, and no path under them or above them', () => {
    const manifest = JSON.stringify({ inputs: ['/w/clerk-ios/Sources/ClerkKit/A.swift', '/w/clerk-ios', '/w/clerk-ios/Examples/', '/w/clerk-ios/Examples/Quickstart/Quickstart.xcodeproj', '/w/clerk-ios/Tests/A.swift', '/w/clerk-ios/Examples/AirbnbClone/App.swift', '/w/clerk-ios-other/x', '/Applications/Xcode.app/x'] });
    assert.deepEqual(pathsOutsideInputs(manifest, '/w/clerk-ios'), ['Examples/AirbnbClone/App.swift', 'Tests/A.swift']);
  });
});

describe('the stage line of a session', () => {
  it('gives each stage in seconds after the first one, in the order they happened', () => {
    const marks = 'start 1000000\ntools-installed 1009000\nresolved 1004400\nbooted 1031000\ndevice-ready 1050000\n';
    assert.equal(
      stageLine(marks, { state: 'stored', key: 'f1a099607eaff57479b9398c783e7ae3', storable: false, why: '' }),
      "verify-remote stages, in seconds after the job's first step: app stored f1a099607eaff57479b9398c783e7ae3; resolved 4, tools-installed 9, booted 31, device-ready 50",
    );
  });
});

describe('the workflows that store and restore', () => {
  const session = readFileSync(join(WORKFLOWS, 'verify-remote.yml'), 'utf8');
  const main = readFileSync(join(WORKFLOWS, 'verify-app-cache.yml'), 'utf8');

  function caches(workflow: string, action: 'restore' | 'save'): readonly string[] {
    const steps = workflow.split(/\n\s*\n/).filter((step) => step.includes(`uses: actions/cache/${action}@`));
    return steps.map((step) => `${/^\s*path: (.+)$/m.exec(step)?.[1]} as ${/^\s*key: (.+)$/m.exec(step)?.[1]}`).sort();
  }

  it('save each directory under the same path and key from a session and from main', () => {
    assert.equal(caches(session, 'save').length, 4);
    assert.deepEqual(caches(main, 'save'), caches(session, 'save'));
  });

  it('restore in a session each thing that is saved, from the path it was saved at', () => {
    const restoredFallback = (line: string): string => line.replace("${{ steps.app.outputs.key || github.run_id }}", '${{ steps.report.outputs.built }}').replace('verify-packages-unresolved', 'verify-packages-${{ steps.app.outputs.pins }}').replaceAll('steps.app.outputs.key', 'steps.report.outputs.store');
    assert.deepEqual(caches(session, 'restore').map(restoredFallback).sort(), caches(session, 'save'));
  });

  it('build the app on main when any build input changes', () => {
    const paths = main.slice(main.indexOf('paths:'), main.indexOf('workflow_dispatch:')).split('\n').map((line) => line.trim().replace(/^- /, ''));
    for (const input of BUILD_INPUTS) assert.ok(paths.includes(input) || paths.includes(`${input}/**`), `${input} is not a path that starts verify-app-cache.yml`);
  });
});

describe('the workflow step that waits for the simulator', () => {
  const lines = readFileSync(join(WORKFLOWS, 'verify-remote.yml'), 'utf8').split('\n').map((line) => line.trim());
  const step = lines.indexOf('- name: Wait for the simulator');
  const first = lines.findIndex((line, at) => at > step && line === 'idle=0');
  const last = lines.findIndex((line, at) => at > first && line.startsWith('xcrun simctl bootstatus'));
  const wait = lines.slice(first, last + 1).join('\n');

  function waited(build: 'running-then-booted' | 'none'): { readonly status: number | null; readonly sleeps: number; readonly booted: string } {
    const work = scratch('verify-simulator-wait-');
    mkdirSync(join(work, 'bin'));
    writeFileSync(join(work, 'slept'), '');
    writeFileSync(join(work, 'bin', 'pgrep'), `#!/bin/sh\nexit ${build === 'none' ? 1 : 0}\n`, { mode: 0o755 });
    writeFileSync(join(work, 'bin', 'sleep'), `#!/bin/sh\necho x >> "${work}/slept"\n[ "$(wc -l < "${work}/slept")" -ge 40 ] && [ ${build === 'none' ? 0 : 1} = 1 ] && touch "${work}/booted"\nexit 0\n`, { mode: 0o755 });
    writeFileSync(join(work, 'bin', 'xcrun'), `#!/bin/sh\necho "$*" > "${work}/xcrun"\n`, { mode: 0o755 });
    const ran = spawnSync('bash', ['-c', wait], { env: { PATH: `${join(work, 'bin')}:${process.env.PATH}`, VERIFY_SESSION_WORK: work, UDID: 'UDID-1' }, encoding: 'utf8', timeout: 60_000 });
    return { status: ran.status, sleeps: readFileSync(join(work, 'slept'), 'utf8').split('\n').length - 1, booted: readFileSync(join(work, 'xcrun'), 'utf8') };
  }

  it('leaves the boot to a running build, however long the build takes', () => {
    assert.ok(step > 0 && first > step && last > first, 'the wait loop is in the workflow');
    assert.deepEqual(waited('running-then-booted'), { status: 0, sleeps: 40, booted: 'simctl bootstatus UDID-1 -b\n' });
  });

  it('boots the simulator itself after 20 seconds with no build running', () => {
    assert.deepEqual(waited('none'), { status: 0, sleeps: 19, booted: 'simctl bootstatus UDID-1 -b\n' });
  });
});
