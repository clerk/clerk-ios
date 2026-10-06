import { test, expect } from '../../fixtures.ts';

test('a new test email reaches the sign-up code screen', async ({ host, screen }) => {
  const email = await host.newEmail();
  await host.launch({ screen: 'auth', authMode: 'signUp' });
  await expect(screen.getByTestId('clerk.auth.start.identifier')).toBeVisible({ timeout: 20_000 });
  await host.fill(screen.getByTestId('clerk.auth.start.identifier'), email);
  await host.tap(screen.getByTestId('clerk.auth.start.continue'));
  await expect(screen.getByTestId('clerk.auth.signUp.code')).toBeVisible({ timeout: 20_000 });
  const state = await host.waitForState((s) => s.signUpStatus === 'missing_requirements');
  expect(state.signedIn).toBe(false);
  await host.screenshot('signup-code');
});
