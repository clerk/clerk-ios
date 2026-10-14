import { test, expect } from '../../fixtures.ts';

test('signInWithPhoneCode reports a phone number that no user holds', async ({ host, screen }) => {
  const phone = await host.newPhone();
  await host.launch();
  await host.tap(screen.getByTestId('e2e.home.customSignIn'));
  await host.fill(screen.getByTestId('verify.customSignIn.phoneNumber'), phone);
  await host.tap(screen.getByTestId('verify.customSignIn.sendCode'));
  await expect(screen.getByTestId('verify.customSignIn.error')).toHaveText("Couldn't find your account.", { timeout: 20_000 });
  await expect(screen.getByTestId('verify.customSignIn.code')).toHaveCount(0);
  await host.screenshot('custom-error');
});
