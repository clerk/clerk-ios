import '../testing/git-env.ts';
import assert from 'node:assert/strict';
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { delimiter, join } from 'node:path';
import { describe, it } from 'node:test';
import { selectBackend } from '../src/core/devices.ts';
import { resolveSpecs } from '../src/core/e2e.ts';
import { STANDARD, declaredIn, planGroups, readSpecText, settingsOf } from '../src/core/instances/settings.ts';
import type { BuildKey, InstanceSettings, ScratchPath } from '../src/core/types.ts';
import { host } from '../src/host.ts';
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

describe('the clerk-ios golden specs', () => {
  const MFA: InstanceSettings = { config: { auth_multi_factor: { required_for_sign_up: true } }, environment: { 'user_settings.sign_up.mfa.required': true } };
  const FORCED_ORG: InstanceSettings = { config: { organization_settings: { force_organization_selection: true } }, environment: { 'organization_settings.force_organization_selection': true } };
  const golden = resolveSpecs(PACKAGE_DIR, { all: true }).map((spec) => ({ spec, ...readSpecText(PACKAGE_DIR, spec.path) }));
  const declarations = golden.map(({ spec, ...text }) => ({ path: spec.path, declared: declaredIn(text, spec.path) }));
  const declaredBy = (file: string) => declarations.find(({ path }) => path.endsWith(`/session-tasks/${file}`))?.declared;

  it('declare forced organization selection or required MFA at sign-up and nothing else', () => {
    assert.deepEqual(declaredBy('choose-organization.e2e.ts'), FORCED_ORG);
    assert.deepEqual(declaredBy('complete-setup-mfa.e2e.ts'), MFA);
    const known = [settingsOf(FORCED_ORG, 'x').key, settingsOf(MFA, 'x').key];
    for (const { path, declared } of declarations) {
      if (declared !== null) assert.ok(known.includes(settingsOf(declared, path).key), path);
    }
  });

  it('plan from the standard settings into three groups, standard first, each asked for by its own first spec', () => {
    const plan = planGroups(golden, STANDARD.key);
    assert.equal(plan.length, 3);
    assert.equal(plan[0]!.settings, STANDARD);
    assert.deepEqual(plan.flatMap((group) => group.specs.map((spec) => spec.path)).sort(), golden.map(({ spec }) => spec.path).sort(), 'every spec is in one group, once');
    for (const group of plan.slice(1)) assert.equal(group.settings.askedBy, group.specs[0]!.path);
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

  it('has a session build E2EHost, wait for the simulator to boot, then install the app it built', () => {
    const steps = sessionDevice({ id: 'UDID-1', platform: 'ios' }).build('/work');
    assert.deepEqual(steps.map((step) => step.command), ['xcodebuild', 'xcrun', 'xcrun']);
    assert.deepEqual(steps[0]!.args.slice(-2), ['-derivedDataPath', '/work/derived']);
    assert.deepEqual(steps[1]!.args, ['simctl', 'bootstatus', 'UDID-1', '-b']);
    assert.deepEqual(steps[2]!.args, ['simctl', 'install', 'UDID-1', '/work/derived/Build/Products/Debug-iphonesimulator/E2EHost.app']);
  });
});
