import { test, expect } from '../../fixtures.ts';
import type { Screen } from 'e2e';
import type { HostFixture } from '../../support/types.ts';

const TAB_SYMBOLS: Record<string, string> = { Home: 'house', Accounts: 'person.2', Organization: 'building.2' };

async function selectTab(host: HostFixture, screen: Screen, name: string): Promise<void> {
  await host.tap(screen.getByTestId(TAB_SYMBOLS[name]!));
}

async function makeActive(host: HostFixture, screen: Screen, name: string): Promise<void> {
  await selectTab(host, screen, 'Accounts');
  await host.tap(screen.getByText(name));
  await selectTab(host, screen, 'Home');
  await expect(screen.getByText(name)).toBeVisible({ timeout: 20_000 });
}

test('members and verified domains follow an organization switch', async ({ host, screen }) => {
  const admin = await host.seedUser();
  const member = await host.seedUser();
  const solo = await host.seedOrganization({ creator: admin });
  const team = await host.seedOrganization({ creator: admin, members: [{ user: member, role: 'org:member' }], suggestDomain: true });

  await host.launch({ signedInAs: admin });
  await host.tap(screen.getByTestId('e2e.home.organizationTabs'));
  await makeActive(host, screen, solo.name);
  await selectTab(host, screen, 'Organization');
  await host.tap(screen.getByRole('button', { name: 'Members' }));
  await expect(screen.getByText(admin.email)).toBeVisible({ timeout: 20_000 });
  await expect(screen.getByText(member.email)).toHaveCount(0);
  await host.screenshot('members-first-org');

  await host.evidence('the open Members screen follows a switch to another organization', async () => {
    await makeActive(host, screen, team.name);
    await selectTab(host, screen, 'Organization');
    await expect(screen.getByText(member.email)).toBeVisible({ timeout: 20_000 });
    await expect(screen.getByText(admin.email)).toBeVisible();
  });
  await host.screenshot('members-after-switch');

  await host.back();
  await host.tap(screen.getByRole('button', { name: 'Verified domains' }));
  await expect(screen.getByText(team.domain)).toBeVisible({ timeout: 20_000 });
  await host.screenshot('domains-team-org');

  await host.evidence('the open Verified domains screen follows a switch to another organization', async () => {
    await makeActive(host, screen, solo.name);
    await selectTab(host, screen, 'Organization');
    await expect(screen.getByText('Add domain')).toBeVisible({ timeout: 20_000 });
    await expect(screen.getByText(team.domain)).toHaveCount(0);
  });
  await host.screenshot('domains-after-switch');
});
