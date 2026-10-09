import { test, expect } from '../../fixtures.ts';

test('the home full-screen sign-in button shows AuthView with no close button', async ({ host, screen }) => {
  await host.launch();
  await host.tap(host.app.signInFullScreen);
  await expect(screen.getByTestId('clerk.auth.start.identifier')).toBeVisible({ timeout: 20_000 });
  await expect(screen.getByTestId('clerk.dismissButton')).toHaveCount(0);
  await host.screenshot('auth-full-screen');
});

test('dismissing AuthView returns to the home, and it opens again', async ({ host, screen }) => {
  const identifier = screen.getByTestId('clerk.auth.start.identifier');
  await host.launch();
  await host.expectSignedOut();
  await host.tap(host.app.signIn);
  await expect(identifier).toBeVisible({ timeout: 20_000 });
  await expect(screen.getByTestId('clerk.auth.start.continue')).toBeVisible();
  await host.screenshot('auth-start');
  await host.tap(screen.getByTestId('clerk.dismissButton'));
  await host.expectSignedOut();
  await expect(identifier).toHaveCount(0);
  await host.screenshot('auth-dismissed');
  await host.tap(host.app.signIn);
  await expect(identifier).toBeVisible({ timeout: 20_000 });
});

test('AuthView opens on the phone field holding the number the app passes as initialIdentifier', async ({ host, screen }) => {
  const user = await host.seedUser({ phone: true, password: true });
  const phone = user.phone!;
  const phoneNumber = screen.getByTestId('clerk.auth.start.phoneNumber');
  await host.launch({ authMode: 'signIn', initialIdentifier: phone });
  await host.tap(host.app.signInFullScreen);
  await expect(phoneNumber.nth(1)).toHaveText('+1', { timeout: 20_000 });
  await expect(phoneNumber.last()).toHaveValue(`(${phone.slice(2, 5)}) ${phone.slice(5, 8)}-${phone.slice(8)}`);
  await expect(screen.getByTestId('clerk.auth.start.identifier')).toHaveCount(0);
  await host.screenshot('auth-initial-identifier');
  await host.tap(screen.getByTestId('clerk.auth.start.continue'));
  await expect(screen.getByTestId('clerk.auth.signIn.password').first()).toBeVisible({ timeout: 20_000 });
  await host.screenshot('auth-initial-identifier-accepted');
});
