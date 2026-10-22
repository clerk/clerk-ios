import { test, expect, CLERK_TEST_CODE } from '../../fixtures.ts';
import type { Screen } from 'e2e';
import type { HostFixture, SeededUser } from '../../support/types.ts';

const TAB_SYMBOLS: Record<string, string> = { Home: 'house', Accounts: 'person.2', Organization: 'building.2' };

async function selectTab(host: HostFixture, screen: Screen, name: string): Promise<void> {
  await host.tap(screen.getByTestId(TAB_SYMBOLS[name]!));
}

async function signInWithCode(host: HostFixture, screen: Screen, user: SeededUser): Promise<void> {
  await host.fill(screen.getByTestId('clerk.auth.start.identifier'), user.email);
  await host.tap(screen.getByTestId('clerk.auth.start.continue'));
  await expect(screen.getByTestId('clerk.auth.signIn.code')).toBeVisible({ timeout: 20_000 });
  await host.fill(screen.getByTestId('clerk.auth.signIn.code'), CLERK_TEST_CODE);
}

test('the embedded account list follows sign-out, sign-in, and an account switch', async ({ host, screen }) => {
  const first = await host.seedUser();
  const second = await host.seedUser();
  const firstOrg = await host.seedOrganization({ creator: first });
  const secondOrg = await host.seedOrganization({ creator: second });

  await host.launch({ signedInAs: first });
  await host.tap(screen.getByTestId('e2e.home.organizationTabs'));
  await selectTab(host, screen, 'Accounts');
  await expect(screen.getByText(firstOrg.name)).toBeVisible({ timeout: 20_000 });
  await host.screenshot('accounts-first-user');

  await host.evidence('switch to another account with the account list mounted', async () => {
    await selectTab(host, screen, 'Home');
    await host.tap(screen.getByTestId('clerk.userButton.profile'));
    await host.tap(screen.getByTestId('clerk.userProfile.row.addAccount'));
    await signInWithCode(host, screen, second);
    await expect(screen.getByTestId('clerk.dismissButton')).toBeVisible({ timeout: 30_000 });
    await host.tap(screen.getByTestId('clerk.dismissButton'));
    await host.expectSignedInAs(second, 30_000);
    await selectTab(host, screen, 'Accounts');
    await expect(screen.getByText(secondOrg.name)).toBeVisible({ timeout: 20_000 });
    await expect(screen.getByText(firstOrg.name)).toHaveCount(0);
  });
  await host.screenshot('accounts-after-switch');

  await host.evidence('sign out and sign in another user with the account list mounted', async () => {
    await selectTab(host, screen, 'Home');
    await host.tap(host.app.signOut);
    await host.expectSignedOut(30_000);
    await host.tap(host.app.signIn);
    await signInWithCode(host, screen, first);
    await host.expectSignedInAs(first, 30_000);
    await selectTab(host, screen, 'Accounts');
    await expect(screen.getByText(firstOrg.name)).toBeVisible({ timeout: 20_000 });
    await expect(screen.getByText(secondOrg.name)).toHaveCount(0);
  });
  await host.screenshot('accounts-after-sign-out-and-in');

  await host.evidence('reopening the account list shows the rows without a spinner', async () => {
    await selectTab(host, screen, 'Home');
    await selectTab(host, screen, 'Accounts');
    await expect(screen.getByText(firstOrg.name)).toBeVisible();
  });
  await host.screenshot('accounts-reappear');
});
