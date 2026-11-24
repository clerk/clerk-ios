import { test, expect, CLERK_TEST_CODE } from '../../fixtures.ts';

test('password: wrong password, then the right one completes a first-factor reverification', async ({ host, screen }) => {
  const user = await host.seedUser({ password: true });
  await host.launch({ signedInAs: user });
  await host.tap(screen.getByTestId('e2e.home.reverify.firstFactor'));
  const password = screen.getByTestId('clerk.reverification.password').first();

  await host.evidence('reverify with a password', async () => {
    await expect(password).toBeVisible({ timeout: 20_000 });
    await host.screenshot('password');
    await host.fill(password, 'Wrong-Password-1!');
    await host.tap(screen.getByTestId('clerk.reverification.continue'));
    await expect(screen.getByText(/incorrect/i).first()).toBeVisible({ timeout: 20_000 });
    await host.screenshot('password-wrong');
    await host.fill(password, user.password!);
    await host.tap(screen.getByTestId('clerk.reverification.continue'));
    await expect(screen.getByTestId('e2e.home.reverificationResult')).toHaveText('Reverified', { timeout: 30_000 });
  });
  await host.screenshot('reverified');
});

test('email code, the other methods, a wrong code, then the right one', async ({ host, screen }) => {
  const user = await host.seedUser({ phone: true });
  await host.launch({ signedInAs: user });
  await host.tap(screen.getByTestId('e2e.home.reverify.firstFactor'));

  await host.evidence('reverify with an email code', async () => {
    const code = screen.getByTestId('clerk.reverification.code');
    await expect(screen.getByText(user.email)).toBeVisible({ timeout: 20_000 });
    await host.screenshot('email-code');
    await host.tap(screen.getByTestId('clerk.reverification.useAnotherMethod'));
    await expect(screen.getByTestId('clerk.reverification.alternativeMethod.phone_code')).toBeVisible({ timeout: 20_000 });
    await host.screenshot('alternatives-first-factor');
    await host.back();
    await host.fill(code, '000000');
    await expect(screen.getByText(/incorrect/i).first()).toBeVisible({ timeout: 20_000 });
    await host.screenshot('email-code-wrong');
    await host.fill(code, CLERK_TEST_CODE);
    await expect(screen.getByTestId('e2e.home.reverificationResult')).toHaveText('Reverified', { timeout: 30_000 });
  });
});

test('phone code as a first factor', async ({ host, screen }) => {
  const user = await host.seedUser({ phone: true });
  await host.launch({ signedInAs: user });
  await host.tap(screen.getByTestId('e2e.home.reverify.firstFactor'));

  await host.evidence('reverify with an SMS code', async () => {
    const another = screen.getByTestId('clerk.reverification.useAnotherMethod');
    await expect(another).toBeVisible({ timeout: 20_000 });
    await host.tap(another);
    await host.tap(screen.getByTestId('clerk.reverification.alternativeMethod.phone_code'));
    await expect(screen.getByText('Enter the code sent to your phone to continue')).toBeVisible({ timeout: 20_000 });
    await host.screenshot('phone-code');
    await host.fill(screen.getByTestId('clerk.reverification.code'), CLERK_TEST_CODE);
    await expect(screen.getByTestId('e2e.home.reverificationResult')).toHaveText('Reverified', { timeout: 30_000 });
  });
});

test('closing the sheet cancels', async ({ host, screen }) => {
  const user = await host.seedUser({ password: true });
  await host.launch({ signedInAs: user });

  await host.evidence('close the reverification sheet', async () => {
    await host.tap(screen.getByTestId('e2e.home.reverify.firstFactor'));
    await expect(screen.getByTestId('clerk.reverification.password').first()).toBeVisible({ timeout: 20_000 });
    await host.tap(screen.getByTestId('clerk.dismissButton'));
    await expect(screen.getByTestId('e2e.home.reverificationResult')).toHaveText('Reverification cancelled', { timeout: 20_000 });
  });
  await host.screenshot('cancelled');
});
