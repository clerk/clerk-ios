import { test, expect } from '../../fixtures.ts';

test('reverify skips the sheet while the session is fresh, and once it is not asks over the sheet the app shows', { timeout: 330_000 }, async ({ host, screen }) => {
  const user = await host.seedUser({ password: true });
  await host.launch({ signedInAs: user });

  await host.evidence('a fresh session runs the protected action without asking', async () => {
    await host.tap(screen.getByTestId('e2e.home.protectedAction'));
    await expect(screen.getByTestId('e2e.home.reverificationResult')).toHaveText('Protected action ran', { timeout: 20_000 });
  });
  await host.screenshot('protected-action-fresh');

  await new Promise((resolve) => setTimeout(resolve, 150_000));

  await host.evidence('a stale session asks over the app\'s sheet, then runs the protected action', async () => {
    await host.tap(screen.getByTestId('e2e.home.protectedActionSheet'));
    const sheetAction = screen.getByTestId('e2e.protectedActionSheet.protectedAction');
    await expect(sheetAction).toBeVisible({ timeout: 20_000 });
    // A tap sent while the sheet is still sliding up can land where the button was a moment ago.
    await new Promise((resolve) => setTimeout(resolve, 1_000));
    await host.tap(sheetAction);
    const password = screen.getByTestId('clerk.reverification.password').first();
    await expect(password).toBeVisible({ timeout: 20_000 });
    await host.screenshot('protected-action-sheet-asks');
    await host.fill(password, user.password!);
    await host.tap(screen.getByTestId('clerk.reverification.continue'));
    await expect(screen.getByTestId('e2e.protectedActionSheet.reverificationResult')).toHaveText('Protected action ran', { timeout: 30_000 });
  });
  await host.screenshot('protected-action-after-reverify');
});
