import { test, expect, CLERK_TEST_CODE } from '../../fixtures.ts';
import { runPassword } from '../../support/clerk.ts';

test('signs up with a phone number, then gives the email and password the instance requires', async ({ host, screen }) => {
  const phone = await host.newPhone();
  const email = await host.newEmail();
  const code = screen.getByTestId('clerk.auth.signUp.code');
  const emailAddress = screen.getByTestId('clerk.auth.signUp.emailAddress').first();
  const password = screen.getByTestId('clerk.auth.signUp.password').first();
  await host.launch({ authMode: 'signUp' });
  await host.tap(host.app.signInFullScreen);
  await host.tap(screen.getByTestId('clerk.auth.start.identifierSwitcher'));
  await host.fill(screen.getByTestId('clerk.auth.start.phoneNumber'), phone.slice(2));
  await host.tap(screen.getByTestId('clerk.auth.start.continue'));
  await expect(screen.getByText('Check your phone')).toBeVisible({ timeout: 20_000 });
  await host.screenshot('signup-phone-code');
  await host.fill(code, CLERK_TEST_CODE);
  await expect(emailAddress).toBeVisible({ timeout: 20_000 });
  await host.fill(emailAddress, email);
  await host.tap(screen.getByTestId('clerk.auth.signUp.continue'));
  await expect(screen.getByText('Check your email')).toBeVisible({ timeout: 20_000 });
  await host.fill(code, CLERK_TEST_CODE);
  await expect(password).toBeVisible({ timeout: 20_000 });
  await host.fill(password, runPassword(host.runId));
  await host.tap(screen.getByTestId('clerk.auth.signUp.continue'));
  await host.expectSignedInAs(email, 30_000);
  await host.screenshot('signed-up-with-phone');
});
