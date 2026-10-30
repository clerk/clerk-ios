import { test, expect, CLERK_TEST_CODE } from '../../fixtures.ts';
import { runPassword } from '@clerk/internal-mobile-e2e/specs/support/clerk';

test('reverifies with a reset password email code and signs in with the new password', async ({ host, screen }) => {
  const user = await host.seedUser({ password: true });
  const newPassword = runPassword(host.runId);
  await host.launch({ signedInAs: user });

  await host.evidence('reverify with a reset password code that sets a new password', async () => {
    await host.tap(screen.getByTestId('e2e.home.customReverify'));
    await host.tap(screen.getByTestId('verify.customReverify.sendCode'));
    const code = screen.getByTestId('verify.customReverify.code');
    await expect(code).toBeVisible({ timeout: 20_000 });
    await expect(screen.getByTestId('verify.customReverify.error')).toHaveCount(0);
    await host.screenshot('reverify-code');
    await host.fill(code, CLERK_TEST_CODE);
    await host.fill(screen.getByTestId('verify.customReverify.newPassword'), newPassword);
    await host.tap(screen.getByTestId('verify.customReverify.verify'));
    await host.expectSignedInAs(user, 30_000);
  });
  await host.screenshot('reverified');

  await host.tap(host.app.signOut);
  await host.expectSignedOut();

  await host.evidence('sign in with the new password', async () => {
    await host.tap(host.app.signIn);
    await host.fill(screen.getByTestId('clerk.auth.start.identifier'), user.email);
    await host.tap(screen.getByTestId('clerk.auth.start.continue'));
    const password = screen.getByTestId('clerk.auth.signIn.password').first();
    await expect(password).toBeVisible({ timeout: 20_000 });
    await host.fill(password, newPassword);
    await host.tap(screen.getByTestId('clerk.auth.signIn.continue'));
    await host.expectSignedInAs(user, 30_000);
  });
  await host.screenshot('signed-in-with-new-password');
});
