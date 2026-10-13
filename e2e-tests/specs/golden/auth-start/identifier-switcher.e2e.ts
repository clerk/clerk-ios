import { test, expect } from '../../fixtures.ts';

test('the phone field offers a switch back to the email or username field', async ({ host, screen }) => {
  const identifier = screen.getByTestId('clerk.auth.start.identifier');
  const phoneNumber = screen.getByTestId('clerk.auth.start.phoneNumber');
  const switcher = screen.getByTestId('clerk.auth.start.identifierSwitcher');
  await host.launch({ authMode: 'signIn' });
  await host.tap(host.app.signIn);
  await expect(identifier).toBeVisible({ timeout: 20_000 });
  await expect(switcher).toHaveText('Use phone number');
  await host.tap(switcher);
  await expect(phoneNumber).toBeVisible();
  await expect(switcher).toHaveText('Use email or username');
  await host.screenshot('switcher-on-phone-field');
  await host.tap(switcher);
  await expect(identifier).toBeVisible();
  await expect(phoneNumber).toHaveCount(0);
  await expect(switcher).toHaveText('Use phone number');
  await host.screenshot('switcher-on-identifier-field');
});
