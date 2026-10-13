import { test, expect } from '../../fixtures.ts';

test('deleting the account from the profile Security screen ends the session and removes the account', async ({ host, screen }) => {
  const user = await host.seedUser();
  await host.launch({ signedInAs: user, authMode: 'signIn' });
  await host.tap(screen.getByTestId('clerk.userButton.profile'));
  await host.tap(screen.getByTestId('clerk.userProfile.row.security'));
  const deleteAccount = screen.getByTestId('clerk.userProfile.security.deleteAccount');
  await screen.scrollUntilVisible(deleteAccount);
  await host.tap(deleteAccount);
  await expect(screen.getByTestId('clerk.userProfile.deleteAccount.confirmation').first()).toBeVisible({ timeout: 20_000 });
  const confirmation = screen.getByRole('textbox');
  await expect(confirmation).toHaveCount(1);
  await host.fill(confirmation, 'DELETE');
  await host.tap(screen.getByTestId('clerk.userProfile.deleteAccount.confirm'));
  await host.expectSignedOut(30_000);
  await host.tap(host.app.signIn);
  await host.fill(screen.getByTestId('clerk.auth.start.identifier'), user.email);
  await host.tap(screen.getByTestId('clerk.auth.start.continue'));
  await expect(screen.getByText("Couldn't find your account.")).toBeVisible({ timeout: 20_000 });
  await host.screenshot('account-deleted');
});
