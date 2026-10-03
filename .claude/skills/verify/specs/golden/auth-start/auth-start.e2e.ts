import { test, expect } from '../../fixtures.ts';

test('the home sign-in button opens AuthView at the identifier field', async ({ host, screen }) => {
  const state = await host.launch({ instance: 'with-email-codes', screen: 'home' });
  expect(state.environmentLoaded).toBe(true);
  expect(state.signedIn).toBe(false);
  await screen.getByTestId('e2e.auth.signIn').tap();
  await expect(screen.getByTestId('clerk.auth.start.identifier')).toBeVisible({ timeout: 20_000 });
  await expect(screen.getByTestId('clerk.auth.start.continue')).toBeVisible();
  await host.screenshot('auth-start');
});

test('verifyScreen auth opens AuthView without a tap', async ({ host, screen }) => {
  const state = await host.launch({ instance: 'with-email-codes', screen: 'auth' });
  expect(state.screen).toBe('auth');
  expect(state.lastError).toBeNull();
  await expect(screen.getByTestId('clerk.auth.start.identifier')).toBeVisible({ timeout: 20_000 });
});
