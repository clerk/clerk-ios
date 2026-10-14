import { test, expect } from '../../fixtures.ts';

test('a ticket sign-in on an MFA-required instance stops on the setup-MFA task', async ({ host, screen }) => {
  const user = await host.seedUser();
  await host.launch({ signedInAs: user, landsOn: host.app.signedOut });
  await host.tap(host.app.signInFullScreen);
  await expect(screen.getByTestId('clerk.auth.sessionTask.setupMfa.authenticatorApp')).toBeVisible({ timeout: 20_000 });
  await expect(screen.getByTestId('clerk.auth.sessionTask.setupMfa.smsCode')).toBeVisible();
  await host.screenshot('session-task');
  await host.tap(screen.getByTestId('clerk.userButton.profile'));
  await expect(screen.getByText(user.email)).toBeVisible({ timeout: 20_000 });
  await host.screenshot('session-task-account');
});
