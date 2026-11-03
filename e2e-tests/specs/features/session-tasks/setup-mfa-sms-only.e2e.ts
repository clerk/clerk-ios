import { test, expect, CLERK_TEST_CODE } from '../../fixtures.ts';
import { runPassword } from '@clerk/internal-mobile-e2e/specs/support/clerk';

test('with MFA required and the authenticator app turned off while the app runs, a sign-up after a relaunch offers only SMS', async ({ host, screen }) => {
  await host.launch({ authMode: 'signUp' });
  await host.useSettings({
    config: { 'auth_multi_factor.required_for_sign_up': true, 'auth_multi_factor.authenticator_app.enabled': false },
    environment: { 'user_settings.sign_up.mfa.required': true, 'user_settings.attributes.authenticator_app.enabled': false },
  });
  await host.launch({ authMode: 'signUp' });
  const email = await host.newEmail();
  await host.tap(host.app.signInFullScreen);
  await host.fill(screen.getByTestId('clerk.auth.start.identifier'), email);
  await host.tap(screen.getByTestId('clerk.auth.start.continue'));
  await expect(screen.getByTestId('clerk.auth.signUp.code')).toBeVisible({ timeout: 20_000 });
  await host.fill(screen.getByTestId('clerk.auth.signUp.code'), CLERK_TEST_CODE);
  const password = screen.getByTestId('clerk.auth.signUp.password').first();
  await expect(password).toBeVisible({ timeout: 20_000 });
  await host.fill(password, runPassword(host.runId));
  await host.tap(screen.getByTestId('clerk.auth.signUp.continue'));
  await host.expectVisible(screen.getByTestId('clerk.auth.sessionTask.setupMfa.smsCode'), 'the SMS code choice of the setup-MFA task', 60_000);
  await expect(screen.getByTestId('clerk.auth.sessionTask.setupMfa.authenticatorApp')).toBeHidden();
  await host.screenshot('sms-only-session-task');
});
