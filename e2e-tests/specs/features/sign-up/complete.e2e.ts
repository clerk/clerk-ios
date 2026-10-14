import { test, expect, CLERK_TEST_CODE } from '../../fixtures.ts';

test('completes sign-up with the test code and a run password', async ({ host, screen }) => {
  const email = await host.newEmail();
  await host.launch({ authMode: 'signUp' });
  await host.tap(host.app.signInFullScreen);
  await host.fill(screen.getByTestId('clerk.auth.start.identifier'), email);
  await host.tap(screen.getByTestId('clerk.auth.start.continue'));
  await expect(screen.getByTestId('clerk.auth.signUp.code')).toBeVisible({ timeout: 20_000 });
  await host.screenshot('signup-code');
  await host.fill(screen.getByTestId('clerk.auth.signUp.code'), CLERK_TEST_CODE);
  await expect(screen.getByTestId('clerk.auth.signUp.password').first()).toBeVisible({ timeout: 20_000 });
  const password = screen.getByRole('textbox');
  await expect(password).toHaveCount(1, { timeout: 20_000 });
  await host.fill(password, `Verify-${host.runId}-Pw1!`);
  await host.tap(screen.getByTestId('clerk.auth.signUp.continue'));
  await host.expectSignedInAs(email, 30_000);
  await host.screenshot('signed-up');
});

test('a sign-up in the sheet from the home closes the sheet and shows the new user', async ({ host, screen }) => {
  const email = await host.newEmail();
  await host.launch({ authMode: 'signUp' });
  await host.tap(host.app.signIn);
  await host.fill(screen.getByTestId('clerk.auth.start.identifier'), email);
  await host.tap(screen.getByTestId('clerk.auth.start.continue'));
  await expect(screen.getByTestId('clerk.auth.signUp.code')).toBeVisible({ timeout: 20_000 });
  await host.fill(screen.getByTestId('clerk.auth.signUp.code'), CLERK_TEST_CODE);
  await expect(screen.getByTestId('clerk.auth.signUp.password').first()).toBeVisible({ timeout: 20_000 });
  const password = screen.getByRole('textbox');
  await expect(password).toHaveCount(1, { timeout: 20_000 });
  await host.fill(password, `Verify-${host.runId}-Pw1!`);
  await host.tap(screen.getByTestId('clerk.auth.signUp.continue'));
  await host.expectSignedInAs(email, 30_000);
  await host.screenshot('signed-up-from-sheet');
});
