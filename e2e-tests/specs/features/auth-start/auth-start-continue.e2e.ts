import { test, expect } from '../../fixtures.ts';

test('Continue stays disabled until the identifier has three characters', async ({ host, screen }) => {
  const identifier = screen.getByTestId('clerk.auth.start.identifier');
  const continueButton = screen.getByTestId('clerk.auth.start.continue');
  await host.launch();
  await host.tap(host.app.signIn);
  await expect(identifier).toBeVisible({ timeout: 20_000 });
  await host.fill(identifier, 'ab');
  await expect(continueButton).toBeDisabled();
  await identifier.pressSequentially('c');
  await expect(identifier).toHaveValue('abc');
  await expect(continueButton).toBeEnabled();
});
