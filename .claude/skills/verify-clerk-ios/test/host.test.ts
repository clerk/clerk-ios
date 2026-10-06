import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, it } from 'node:test';
import { selectBackend } from '../src/core/devices.ts';
import { resolveSpecs } from '../src/core/e2e.ts';
import { STANDARD, declaredIn, planGroups, settingsOf } from '../src/core/instances/settings.ts';
import type { InstanceSettings, VerifyFailure } from '../src/core/types.ts';
import { featureMapCheck } from '../src/core/verbs.ts';
import { host } from '../src/host.ts';
import { localIosBackend } from '../src/platform/ios/local.ts';

const SKILL_DIR = join(import.meta.dirname, '..');

describe('the clerk-ios Feature Map', () => {
  it('has a feature file and a golden spec for every feature the host lists', () => {
    const check = featureMapCheck(SKILL_DIR, host.features);
    assert.equal(check.ok, true, check.detail);
  });
});

describe('the clerk-ios golden specs', () => {
  const MFA: InstanceSettings = { config: { auth_multi_factor: { required_for_sign_up: true } }, environment: { 'user_settings.sign_up.mfa.required': true } };
  const FORCED_ORG: InstanceSettings = { config: { organization_settings: { force_organization_selection: true } }, environment: { 'organization_settings.force_organization_selection': true } };
  const golden = resolveSpecs(SKILL_DIR, { all: true }).map((spec) => ({ spec, source: readFileSync(join(SKILL_DIR, spec.path), 'utf8') }));
  const declarations = golden.map(({ spec, source }) => ({ path: spec.path, declared: declaredIn(source, spec.path) }));
  const declaredBy = (file: string) => declarations.find(({ path }) => path.endsWith(`/session-tasks/${file}`))?.declared;

  it('declare forced organization selection or required MFA at sign-up and nothing else', () => {
    assert.deepEqual(declaredBy('choose-organization.e2e.ts'), FORCED_ORG);
    assert.deepEqual(declaredBy('setup-mfa.e2e.ts'), MFA);
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

describe('the clerk-ios host', () => {
  it('runs the simulator on a Mac, and on any other system says that the simulator needs macOS', () => {
    const on = (os: NodeJS.Platform) => selectBackend({ ...host, backends: [localIosBackend({ os })] }, 'ios');
    assert.deepEqual(host.backends.map((b) => b.kind), ['local']);
    assert.equal(on('darwin').kind, 'local');
    assert.throws(() => on('linux'), (error: VerifyFailure) => {
      assert.equal(error.code, 'UNSUPPORTED');
      assert.equal(error.message, 'no ios backend runs on this machine (local: the iOS simulator needs macOS and this machine runs linux)');
      assert.equal(error.fix, 'run on a Mac with Xcode');
      return true;
    });
  });
});
