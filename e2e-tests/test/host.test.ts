import '@clerk/internal-mobile-e2e/testing/git-env';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { delimiter, join } from 'node:path';
import { describe, it } from 'node:test';
import { selectBackend } from '@clerk/internal-mobile-e2e/core/devices';
import type { BuildKey, ScratchPath } from '@clerk/internal-mobile-e2e/core/types';
import { host } from '../src/host.ts';
import { BUILD_INPUTS } from '../src/host-app.ts';
import { localIosBackend } from '../src/platform/ios/local.ts';
import sessionDevice from '../src/platform/ios/session-device.ts';

const PACKAGE_DIR = join(import.meta.dirname, '..');
const WORKTREE = join(PACKAGE_DIR, '..');

describe('the clerk-ios build inputs', () => {
  it('cover the Xcode project that defines the E2EHost target, so a change to it makes a new build key', () => {
    const inputs = host.buildInputs('ios', 'local');
    const project = 'Examples/Quickstart/Quickstart.xcodeproj/project.pbxproj';
    assert.match(readFileSync(join(WORKTREE, project), 'utf8'), /E2EHost/);
    assert.ok(inputs.some((input) => project === input || project.startsWith(`${input}/`)), `${project} is under none of ${inputs.join(', ')}`);
    for (const input of inputs) assert.ok(existsSync(join(WORKTREE, input)), input);
  });
});

describe('the clerk-ios host build', () => {
  it('runs xcodebuild without the Clerk and agent keys of the environment, and with the rest of it', async () => {
    const scratch = mkdtempSync(join(tmpdir(), 'verify-host-build-'));
    mkdirSync(join(scratch, 'bin'));
    writeFileSync(join(scratch, 'bin', 'xcodebuild'), '#!/bin/sh\nfor derived; do :; done\nmkdir -p "$derived/Build/Products/Debug-iphonesimulator/E2EHost.app"\nenv > "$derived/env"\n', { mode: 0o755 });
    const before = { ...process.env };
    const set = {
      CLERK_PLATFORM_API_KEY: 'ak_platform',
      CLERK_PLATFORM_API_KEY_FILE: '/home/x/key',
      VERIFY_PLATFORM_KEY_REFERENCE: 'op://vault/item',
      CLERK_SECRET_KEY: 'sk_test_instance',
      AI_GATEWAY_API_KEY: 'vck_gateway',
      AI_GATEWAY_API_KEY_FILE: '/home/x/gateway',
      VERIFY_HOST_BUILD_MARK: 'kept',
    };
    Object.assign(process.env, set, { PATH: `${join(scratch, 'bin')}${delimiter}${process.env.PATH}` });
    try {
      const built = await host.build('ios', 'ios-0000' as BuildKey, join(scratch, 'build') as ScratchPath, () => {});
      assert.equal(built.path, join(scratch, 'build', 'E2EHost.app'));
      const seen = readFileSync(join(scratch, 'derived', 'env'), 'utf8').split('\n');
      assert.deepEqual(seen.filter((line) => Object.keys(set).includes(line.split('=')[0]!)), ['VERIFY_HOST_BUILD_MARK=kept']);
    } finally {
      for (const name of Object.keys(process.env)) if (!(name in before)) delete process.env[name];
      Object.assign(process.env, before);
      rmSync(scratch, { recursive: true, force: true });
    }
  });
});

describe('the clerk-ios host with a remote device', () => {
  it('runs the simulator locally on a Mac and remotely anywhere else', () => {
    const remote = host.backends.find((b) => b.kind === 'remote')!;
    const on = (os: NodeJS.Platform) => selectBackend({ ...host, backends: [localIosBackend({ os }), remote] }, 'ios', undefined, null);
    assert.deepEqual(host.backends.map((b) => b.kind), ['local', 'remote']);
    assert.equal(on('darwin').backend.kind, 'local');
    const onLinux = on('linux');
    assert.equal(onLinux.backend.kind, 'remote');
    assert.match(onLinux.why, /^local is out: the iOS simulator needs macOS and this machine runs linux; /);
  });

  it('starts a session on the free GitHub runner whose image verify-app-cache.yml stores the app for, unless --runner names another', () => {
    const remote = host.backends.find((b) => b.kind === 'remote')!;
    assert.deepEqual(remote.availability(), { usable: true, why: 'the device runs on a CI runner (xcode-27 unless --runner names another), started through verify-remote.yml on clerk/clerk-ios' });
  });

  it('has a session run one build command for the device, in the checkout, that installs a stored app or builds one', () => {
    const steps = sessionDevice({ id: 'UDID-1', platform: 'ios' }).build('/work');
    assert.deepEqual(steps, [{ command: process.execPath, args: [join(PACKAGE_DIR, 'src', 'platform', 'ios', 'session-build.ts'), 'build', '/work', 'UDID-1'], cwd: `${WORKTREE}/` }]);
  });

  it('has a session build uncommitted changes only to the paths the app builds from', () => {
    assert.equal(sessionDevice({ id: 'UDID-1', platform: 'ios' }).inputs, BUILD_INPUTS);
    assert.ok(BUILD_INPUTS.includes('Sources'));
  });

  it('has the session workflow start on the two runner labels this repository uses, and fail for any other', () => {
    const lines = readFileSync(join(WORKTREE, '.github', 'workflows', 'verify-remote.yml'), 'utf8').split('\n').map((line) => line.trim());
    const first = lines.indexOf('case "$RUNNER_LABEL" in');
    const check = lines.slice(first, lines.indexOf('esac', first) + 1).join('\n');
    const checked = (label: string) => {
      const ran = spawnSync('bash', ['-c', check], { env: { PATH: process.env.PATH, RUNNER_LABEL: label }, encoding: 'utf8' });
      return { status: ran.status, stdout: ran.stdout };
    };
    assert.ok(first > 0, 'the label check is in the workflow');
    for (const label of ['xcode-27', 'ubuntu-latest']) assert.deepEqual(checked(label), { status: 0, stdout: '' }, label);
    assert.deepEqual(checked('blacksmith-6vcpu-macos-27'), { status: 1, stdout: '::error title=verify-remote::no session started: the runner label blacksmith-6vcpu-macos-27 is not xcode-27 or ubuntu-latest\n' });
  });
});
