import { test, expect } from '../../fixtures.ts';

test('creating an organization from OrganizationSwitcher makes it active', async ({ host, screen }) => {
  const user = await host.seedUser();
  const state = await host.launch({ signedInAs: user, screen: 'orgSwitcher' });
  expect(state.orgId).toBeNull();
  await host.tap(screen.getByText('Personal account'));
  await host.tap(screen.getByTestId('clerk.organization.accountList.createOrganization'));
  const name = `Verify ${state.runId}`;
  await host.fill(screen.getByTestId('clerk.organization.profileForm.name'), name);
  await host.tap(screen.getByTestId('clerk.organization.profileForm.submit'));
  const skip = screen.getByRole('button', { name: 'Skip' });
  await expect(skip).toBeVisible({ timeout: 20_000 });
  await host.tap(skip);
  const created = await host.waitForState((s) => s.orgId !== null, 30_000);
  expect(created.userId).toBe(user.id);
  await expect(screen.getByText(name)).toBeVisible({ timeout: 20_000 });
  await host.screenshot('org-created');
});
