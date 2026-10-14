import { test, expect, CLERK_TEST_CODE } from '../../fixtures.ts';

test('a sign-up on an MFA-required instance moves straight into the setup-MFA task', async ({ host, screen }) => {
  const email = await host.newEmail();
  await host.launch({ authMode: 'signUp' });
  await host.tap(host.app.signInFullScreen);
  await host.fill(screen.getByTestId('clerk.auth.start.identifier'), email);
  await host.tap(screen.getByTestId('clerk.auth.start.continue'));
  await expect(screen.getByTestId('clerk.auth.signUp.code')).toBeVisible({ timeout: 20_000 });
  await host.fill(screen.getByTestId('clerk.auth.signUp.code'), CLERK_TEST_CODE);
  const password = screen.getByTestId('clerk.auth.signUp.password').first();
  await expect(password).toBeVisible({ timeout: 20_000 });
  await host.fill(password, `Verify-${host.runId}-Pw1!`);
  await host.tap(screen.getByTestId('clerk.auth.signUp.continue'));
  await host.expectVisible(screen.getByTestId('clerk.auth.sessionTask.setupMfa.authenticatorApp'), 'the authenticator app choice of the setup-MFA task', 60_000);
  await expect(screen.getByTestId('clerk.auth.sessionTask.setupMfa.smsCode')).toBeVisible();
  await host.screenshot('sign-up-session-task');
  await host.tap(screen.getByTestId('clerk.userButton.profile'));
  await expect(screen.getByText(email)).toBeVisible({ timeout: 20_000 });
  await host.screenshot('sign-up-session-task-account');
});
