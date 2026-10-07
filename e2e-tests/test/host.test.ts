import '../testing/git-env.ts';
import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, it } from 'node:test';
import { resolveSpecs } from '../src/core/e2e.ts';
import { STANDARD, declaredIn, planGroups, readSpecText, settingsOf } from '../src/core/instances/settings.ts';
import type { InstanceSettings } from '../src/core/types.ts';
import { host } from '../src/host.ts';

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
