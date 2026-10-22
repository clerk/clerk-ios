import { test, expect, CLERK_TEST_CODE } from '../../fixtures.ts';
import { asShownByClerk } from '../../phone.ts';

test('signs in with the SMS code from the AuthView sheet the home opens', async ({ host, screen }) => {
  const user = await host.seedUser({ phone: true, password: true });
  await host.launch();
  await host.expectSignedOut();
  await host.tap(host.app.signIn);
  await host.tap(screen.getByTestId('clerk.auth.start.identifierSwitcher'));
  await host.fill(screen.getByTestId('clerk.auth.start.phoneNumber'), user.phone!.slice(2));
  await host.tap(screen.getByTestId('clerk.auth.start.continue'));
  await expect(screen.getByTestId('clerk.auth.signIn.password').first()).toBeVisible({ timeout: 20_000 });
  await host.screenshot('phone-password-screen');
  await host.tap(screen.getByTestId('clerk.auth.signIn.useAnotherMethod'));
  const smsCode = screen.getByTestId('clerk.auth.signIn.alternativeMethod.phone_code');
  await expect(smsCode).toBeVisible({ timeout: 20_000 });
  await host.screenshot('phone-methods');
  await host.tap(smsCode);
  const code = screen.getByTestId('clerk.auth.signIn.code');
  await expect(code).toBeVisible({ timeout: 20_000 });
  await expect(screen.getByText('Check your phone')).toBeVisible();
  await expect(screen.getByText(asShownByClerk(user.phone!)).first()).toBeVisible();
  await host.screenshot('phone-code-screen');
  await host.fill(code, CLERK_TEST_CODE);
  await host.expectSignedInAs(user, 30_000);
  await host.screenshot('signed-in-with-phone-code');
});
