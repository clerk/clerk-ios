import { test, expect } from '../../fixtures.ts';

test('creating an organization from the embedded account list returns to the list with the new organization', async ({ host, screen }) => {
  const user = await host.seedUser();
  await host.launch({ signedInAs: user });
  await host.tap(screen.getByTestId('e2e.home.organizationTabs'));
  await host.tap(screen.getByTestId('person.2'));
  await host.tap(screen.getByTestId('clerk.organization.accountList.createOrganization'));
  const name = host.newOrganizationName();
  await host.fill(screen.getByTestId('clerk.organization.profileForm.name'), name);
  await host.tap(screen.getByTestId('clerk.organization.profileForm.submit'));
  const skip = screen.getByRole('button', { name: 'Skip' });
  await expect(skip).toBeVisible({ timeout: 20_000 });
  await host.tap(skip);
  await expect(screen.getByText(name)).toBeVisible({ timeout: 20_000 });
  await expect(screen.getByTestId('clerk.organization.accountList.createOrganization')).toBeVisible({ timeout: 20_000 });
  await expect(screen.getByTestId('house')).toBeVisible();
  await host.screenshot('accounts-after-create');
});
