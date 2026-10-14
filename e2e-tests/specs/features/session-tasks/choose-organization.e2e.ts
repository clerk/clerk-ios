import { test, expect } from '../../fixtures.ts';

test('a ticket sign-in with forced organization selection stops on the organization task', async ({ host, screen }) => {
  const user = await host.seedUser();
  await host.launch({ signedInAs: user, landsOn: host.app.signedOut });
  await host.tap(host.app.signInFullScreen);
  await expect(screen.getByTestId('clerk.organization.profileForm.name')).toBeVisible({ timeout: 20_000 });
  await host.screenshot('choose-organization-task');
  await host.tap(screen.getByTestId('clerk.userButton.profile'));
  await expect(screen.getByText(user.email)).toBeVisible({ timeout: 20_000 });
});
