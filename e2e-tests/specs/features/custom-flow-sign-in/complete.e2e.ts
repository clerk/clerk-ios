import { test, expect, CLERK_TEST_CODE } from '../../fixtures.ts';

test('a custom form signs in with the SMS code', async ({ host, screen }) => {
  const user = await host.seedUser({ phone: true });
  await host.launch();
  await host.tap(screen.getByTestId('e2e.home.customSignIn'));
  await host.fill(screen.getByTestId('verify.customSignIn.phoneNumber'), user.phone!);
  await host.tap(screen.getByTestId('verify.customSignIn.sendCode'));
  await expect(screen.getByTestId('verify.customSignIn.code')).toBeVisible({ timeout: 20_000 });
  await expect(screen.getByTestId('verify.customSignIn.verifyCode')).toBeVisible();
  await expect(screen.getByTestId('verify.customSignIn.error')).toHaveCount(0);
  await host.screenshot('custom-code');
  await host.fill(screen.getByTestId('verify.customSignIn.code'), CLERK_TEST_CODE);
  await host.tap(screen.getByTestId('verify.customSignIn.verifyCode'));
  await host.expectSignedInAs(user, 30_000);
  await host.screenshot('custom-signed-in');
});
