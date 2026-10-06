import { test, expect, type InstanceSettings } from '../../fixtures.ts';

export const instanceSettings: InstanceSettings = {
  config: { auth_multi_factor: { required_for_sign_up: true } },
  environment: { 'user_settings.sign_up.mfa.required': true },
};

test('a ticket sign-in on an MFA-required instance stops on the setup-MFA task', async ({ host, screen }) => {
  const user = await host.seedUser();
  const state = await host.launch({ signedInAs: user, screen: 'auth' });
  expect(state.ticket).toBe('succeeded');
  expect(state.userId).toBe(user.id);
  expect(state.sessionStatus).toBe('pending');
  expect(state.pendingTasks).toContain('setup-mfa');
  await expect(screen.getByTestId('clerk.auth.sessionTask.setupMfa.authenticatorApp')).toBeVisible({ timeout: 20_000 });
  await expect(screen.getByTestId('clerk.auth.sessionTask.setupMfa.smsCode')).toBeVisible();
  await host.screenshot('session-task');
});
