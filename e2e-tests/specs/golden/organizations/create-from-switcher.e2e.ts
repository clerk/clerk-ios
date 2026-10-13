import { test, expect } from '../../fixtures.ts';

test('creating an organization from OrganizationSwitcher makes it active', async ({ host, screen }) => {
  const user = await host.seedUser();
  await host.launch({ signedInAs: user });
  await host.tap(screen.getByText('Personal account'));
  await host.tap(screen.getByTestId('clerk.organization.accountList.createOrganization'));
  const name = `Verify ${host.runId}`;
  await host.fill(screen.getByTestId('clerk.organization.profileForm.name'), name);
  await host.tap(screen.getByTestId('clerk.organization.profileForm.submit'));
  const skip = screen.getByRole('button', { name: 'Skip' });
  await expect(skip).toBeVisible({ timeout: 20_000 });
  await host.tap(skip);
  await host.expectSignedInAs(user, 30_000);
  await expect(screen.getByText(name)).toBeVisible({ timeout: 20_000 });
  await expect(screen.getByText('Personal account')).toHaveCount(0);
  await host.screenshot('org-created');
});
