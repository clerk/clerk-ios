import { test, expect, CLERK_TEST_CODE } from '../../fixtures.ts';

test('completes sign-up with the test code and a run password', { tags: ['form-entry'] }, async ({ host, screen }) => {
  const email = await host.newEmail();
  const state0 = await host.launch({ screen: 'auth', authMode: 'signUp' });
  await expect(screen.getByTestId('clerk.auth.start.identifier')).toBeVisible({ timeout: 20_000 });
  await host.fill(screen.getByTestId('clerk.auth.start.identifier'), email);
  await host.tap(screen.getByTestId('clerk.auth.start.continue'));
  await expect(screen.getByTestId('clerk.auth.signUp.code')).toBeVisible({ timeout: 20_000 });
  await host.screenshot('signup-code');
  await host.fill(screen.getByTestId('clerk.auth.signUp.code'), CLERK_TEST_CODE);
  const password = screen.getByTestId('clerk.auth.signUp.password');
  await expect(password).toBeVisible({ timeout: 20_000 });
  await host.fill(password, `Verify-${state0.runId}-Pw1!`);
  await host.tap(screen.getByTestId('clerk.auth.signUp.continue'));
  const state = await host.waitForState((s) => s.signedIn && s.sessionStatus === 'active', 30_000);
  expect(state.userId).not.toBeNull();
  await host.screenshot('signed-up');
});
