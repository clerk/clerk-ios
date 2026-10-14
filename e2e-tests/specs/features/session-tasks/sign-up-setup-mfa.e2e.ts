import { test, expect, CLERK_TEST_CODE } from '../../fixtures.ts';

test('a sign-up on an MFA-required instance moves straight into the setup-MFA task', async ({ host, screen }) => {
  const email = await host.newEmail();
  await host.launch({ authMode: 'signUp' });
  await host.tap(host.app.signInFullScreen);
  await host.fill(screen.getByTestId('clerk.auth.start.identifier'), email);
  await host.tap(screen.getByTestId('clerk.auth.start.continue'));
  await expect(screen.getByTestId('clerk.auth.signUp.code')).toBeVisible({ timeout: 20_000 });
  await host.fill(screen.getByTestId('clerk.auth.signUp.code'), CLERK_TEST_CODE);
  await expect(screen.getByTestId('clerk.auth.signUp.password').first()).toBeVisible({ timeout: 20_000 });
  const password = screen.getByRole('textbox');
  await expect(password).toHaveCount(1, { timeout: 20_000 });
  await host.fill(password, `Verify-${host.runId}-Pw1!`);
  await host.tap(screen.getByTestId('clerk.auth.signUp.continue'));
  const task = screen.getByTestId('clerk.auth.sessionTask.setupMfa.authenticatorApp');
  const savePassword = screen.getByText('Save Password?');
  for (const until = Date.now() + 30_000; Date.now() < until && (await savePassword.count()) === 0 && (await task.count()) === 0; ) {
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  for (const until = Date.now() + 10_000; Date.now() < until && (await savePassword.count()) === 0; ) {
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  if ((await savePassword.count()) > 0) {
    await host.tap(screen.getByRole('button', { name: 'Not Now' }));
    await expect(savePassword).toHaveCount(0, { timeout: 10_000 });
  }
  await expect(task).toBeVisible({ timeout: 20_000 });
  await expect(screen.getByTestId('clerk.auth.sessionTask.setupMfa.smsCode')).toBeVisible();
  await host.screenshot('sign-up-session-task');
  await host.tap(screen.getByTestId('clerk.userButton.profile'));
  await expect(screen.getByText(email)).toBeVisible({ timeout: 20_000 });
  await host.screenshot('sign-up-session-task-account');
});
