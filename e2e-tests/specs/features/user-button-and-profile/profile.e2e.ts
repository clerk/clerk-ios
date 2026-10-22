import { test, expect } from '../../fixtures.ts';
import { asShownByClerk } from '../../phone.ts';

test('the home UserButton opens the profile of the signed-in user', async ({ host, screen }) => {
  const user = await host.seedUser();
  await host.launch({ signedInAs: user });
  await host.tap(screen.getByTestId('clerk.userButton.profile'));
  await expect(screen.getByRole('button', { name: 'Edit profile' })).toBeVisible({ timeout: 20_000 });
  await expect(screen.getByTestId(`clerk.userProfile.currentUser.${user.id}`).first()).toBeVisible();
  await host.screenshot('user-button-profile');
  await host.tap(screen.getByTestId('clerk.userProfile.row.manageAccount'));
  await expect(screen.getByText(user.email)).toBeVisible({ timeout: 20_000 });
  await host.screenshot('profile');
});

test('Manage account and Security open from the profile, and back returns to it from each', async ({ host, screen }) => {
  const user = await host.seedUser({ phone: true });
  await host.launch({ signedInAs: user });
  await host.tap(screen.getByTestId('clerk.userButton.profile'));
  const profileRoot = screen.getByRole('button', { name: 'Edit profile' });
  await expect(profileRoot).toBeVisible({ timeout: 20_000 });
  await host.screenshot('profile-before-sections');
  await host.tap(screen.getByTestId('clerk.userProfile.row.manageAccount'));
  await expect(screen.getByText(user.email)).toBeVisible({ timeout: 20_000 });
  await expect(screen.getByText('PHONE NUMBERS')).toBeVisible();
  await expect(screen.getByText(asShownByClerk(user.phone!))).toBeVisible();
  await expect(screen.getByText('CONNECTED ACCOUNTS')).toBeVisible();
  await host.screenshot('manage-account-sections');
  await host.back();
  await expect(profileRoot).toBeVisible({ timeout: 20_000 });
  await host.tap(screen.getByTestId('clerk.userProfile.row.security'));
  const activeDevices = screen.getByText('ACTIVE DEVICES');
  await expect(activeDevices).toBeVisible({ timeout: 20_000 });
  await host.back();
  await expect(profileRoot).toBeVisible({ timeout: 20_000 });
  await expect(activeDevices).toHaveCount(0);
  await host.screenshot('profile-after-back');
});

test('the Add account row opens sign-in for a second account', async ({ host, screen }) => {
  const user = await host.seedUser();
  await host.launch({ signedInAs: user });
  await host.tap(screen.getByTestId('clerk.userButton.profile'));
  await host.tap(screen.getByTestId('clerk.userProfile.row.addAccount'));
  await expect(screen.getByTestId('clerk.auth.start.identifier')).toBeVisible({ timeout: 20_000 });
  await host.screenshot('add-account');
});

test('the home sign-out button ends the session', async ({ host }) => {
  const user = await host.seedUser();
  await host.launch({ signedInAs: user });
  await host.tap(host.app.signOut);
  await host.expectSignedOut();
  await expect(host.app.signIn).toBeVisible();
  await host.screenshot('signed-out');
});

test('the profile Sign out row ends the session', async ({ host, screen }) => {
  const user = await host.seedUser();
  await host.launch({ signedInAs: user });
  await host.tap(screen.getByTestId('clerk.userButton.profile'));
  await host.tap(screen.getByTestId('clerk.userProfile.row.signOut'));
  await host.expectSignedOut();
});
