import { randomBytes } from 'node:crypto';
import { test, expect } from '../../fixtures.ts';
import type { Locator, Screen } from 'e2e';
import type { HostFixture, SeededUser } from '../../support/types.ts';

function atCenter(target: Locator): Locator {
  const tap = async (): Promise<void> => {
    await expect(target).toBeVisible({ timeout: 20_000 });
    const box = await target.boundingBox();
    if (!box) throw new Error('the target has no box');
    await target.tap({ position: { x: box.width / 2, y: box.height / 2 } });
  };
  return Object.assign(Object.create(target) as Locator, { tap });
}

async function selectTab(host: HostFixture, screen: Screen, name: string): Promise<void> {
  await host.tap(atCenter(screen.getByRole('tab', { name })));
  await expect(screen.getByRole('tab', { name, selected: true })).toBeVisible({ timeout: 20_000 });
}

async function openNewOrganizationProfile(host: HostFixture, screen: Screen, user: SeededUser, name: string): Promise<void> {
  await host.launch({ signedInAs: user });
  await host.tap(screen.getByText('Personal account'));
  await host.tap(screen.getByTestId('clerk.organization.accountList.createOrganization'));
  await host.fill(screen.getByTestId('clerk.organization.profileForm.name'), name);
  await host.tap(screen.getByTestId('clerk.organization.profileForm.submit'));
  const skip = screen.getByRole('button', { name: 'Skip' });
  await expect(skip).toBeVisible({ timeout: 20_000 });
  await host.tap(skip);
  await host.expectSignedInAs(user, 30_000);
  await host.tap(screen.getByText(name));
  await expect(screen.getByText('Admin')).toBeVisible({ timeout: 20_000 });
  await expect(screen.getByRole('button', { name: 'Switch account' })).toBeVisible();
  await host.tap(screen.getByRole('button', { name: 'Manage' }));
  await expect(screen.getByRole('button', { name: 'Update profile' })).toBeVisible({ timeout: 20_000 });
}

test('the organization creator opens every row of the organization profile and deletes the organization', async ({ host, screen, device }) => {
  const user = await host.seedUser();
  const name = `Profile ${host.runId} ${randomBytes(3).toString('hex')}`;
  await openNewOrganizationProfile(host, screen, user, name);
  await expect(screen.getByRole('button', { name: 'Members' })).toBeVisible();
  await expect(screen.getByRole('button', { name: 'Verified domains' })).toBeVisible();
  await expect(screen.getByRole('button', { name: 'Leave organization' })).toBeVisible();
  await expect(screen.getByRole('button', { name: 'Delete organization' })).toBeVisible();
  await host.screenshot('org-profile');

  await host.tap(screen.getByRole('button', { name: 'Members' }));
  await expect(screen.getByText('You')).toBeVisible({ timeout: 20_000 });
  await expect(screen.getByText(user.email)).toBeVisible();
  await expect(screen.getByRole('button', { name: 'Invite' })).toBeVisible();
  await host.screenshot('org-members');

  await selectTab(host, screen, 'Invitations');
  await expect(screen.getByText('No invitations sent')).toBeVisible({ timeout: 20_000 });
  await host.screenshot('org-invitations-empty');
  await selectTab(host, screen, 'Requests');
  await expect(screen.getByText('No membership requests')).toBeVisible({ timeout: 20_000 });
  await host.screenshot('org-requests-empty');
  await selectTab(host, screen, 'Members');
  await host.fill(atCenter(screen.getByRole('textbox')), 'zz-no-such-member');
  await expect(screen.getByText('No members found')).toBeVisible({ timeout: 20_000 });
  await host.screenshot('org-members-no-match');

  await device.back();
  await host.tap(screen.getByRole('button', { name: 'Verified domains' }));
  await expect(screen.getByText('Add domain')).toBeVisible({ timeout: 20_000 });
  await expect(screen.getByText('No verified domains')).toHaveCount(0);
  await host.screenshot('org-domains');

  await device.back();
  await host.tap(screen.getByRole('button', { name: 'Update profile' }));
  await expect(screen.getByTestId('clerk.organization.profileForm.name')).toBeVisible({ timeout: 20_000 });
  await host.screenshot('org-update-profile');
  await host.tap(screen.getByRole('button', { name: 'Cancel' }));
  await host.tap(screen.getByRole('button', { name: 'Leave organization' }));
  await expect(screen.getByText(`Type "${name}" below to continue.`)).toBeVisible({ timeout: 20_000 });
  await host.screenshot('org-leave-confirmation');
  await host.tap(screen.getByRole('button', { name: 'Cancel' }));

  await host.tap(screen.getByRole('button', { name: 'Delete organization' }));
  await expect(screen.getByText('Are you sure you want to delete this organization?')).toBeVisible({ timeout: 20_000 });
  await host.fill(screen.getByRole('textbox'), name);
  await host.screenshot('org-delete-confirmation');
  await host.tap(screen.getByRole('button', { name: 'Delete organization' }).last());
  await host.expectSignedInAs(user, 30_000);
  await expect(screen.getByText('Personal account')).toBeVisible({ timeout: 20_000 });
  await expect(screen.getByText(name)).toHaveCount(0);
  await host.screenshot('org-deleted');
});

test('Invite on the Members screen sends an invitation that the Invitations tab lists', async ({ host, screen }) => {
  const user = await host.seedUser();
  const invitee = await host.newEmail();
  await openNewOrganizationProfile(host, screen, user, `Invite ${host.runId} ${randomBytes(3).toString('hex')}`);
  await host.tap(screen.getByRole('button', { name: 'Members' }));
  await host.tap(atCenter(screen.getByRole('button', { name: 'Invite' })));
  await host.fill(screen.getByRole('textbox', { name: 'Enter email addresses' }), invitee);
  await host.tap(screen.getByRole('button', { name: 'Send invitations' }));
  await selectTab(host, screen, 'Invitations');
  await expect(screen.getByText(invitee)).toBeVisible({ timeout: 20_000 });
  await host.screenshot('invitation-sent');
});

test('Update profile renames the organization', async ({ host, screen }) => {
  const user = await host.seedUser();
  const renamed = `Renamed ${host.runId}`;
  await openNewOrganizationProfile(host, screen, user, `Rename ${host.runId.replaceAll('-', '')}${randomBytes(3).toString('hex')}`);
  await host.tap(screen.getByRole('button', { name: 'Update profile' }));
  const nameField = screen.getByTestId('clerk.organization.profileForm.name');
  await host.tap(nameField);
  await nameField.clear();
  await expect(nameField).toHaveValue('');
  await host.fill(nameField, renamed);
  await expect(nameField).toHaveValue(renamed);
  await host.tap(screen.getByTestId('clerk.organization.profileForm.submit'));
  await expect(screen.getByTestId('clerk.organization.profileForm.name')).toHaveCount(0, { timeout: 20_000 });
  await expect(screen.getByRole('button', { name: 'Update profile' })).toBeVisible();
  await expect(screen.getByText(renamed)).toHaveCount(1, { timeout: 20_000 });
  await expect(screen.getByText(renamed)).toBeVisible();
  await host.screenshot('org-renamed');
});
