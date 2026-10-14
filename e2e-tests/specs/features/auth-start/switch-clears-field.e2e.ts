import { test, expect } from '../../fixtures.ts';

test('switching between the email and phone fields clears the field the user leaves', async ({ host, screen }) => {
  const identifier = screen.getByTestId('clerk.auth.start.identifier');
  const phoneNumber = screen.getByTestId('clerk.auth.start.phoneNumber');
  const switcher = screen.getByTestId('clerk.auth.start.identifierSwitcher');
  const email = await host.newEmail();
  const phoneDigits = (await host.newPhone()).slice(2);

  await host.launch();
  await host.tap(host.app.signIn);
  await expect(identifier).toBeVisible({ timeout: 20_000 });

  await host.fill(identifier, email);
  await expect(identifier).toHaveValue(email);
  await host.screenshot('email-typed');
  await host.tap(switcher);
  await expect(phoneNumber).toBeVisible({ timeout: 10_000 });
  await host.tap(switcher);
  await expect(identifier).toBeVisible({ timeout: 10_000 });
  await expect(identifier).toHaveValue('');
  await host.screenshot('email-cleared');

  await host.tap(switcher);
  await expect(phoneNumber).toBeVisible({ timeout: 10_000 });
  await host.fill(phoneNumber, phoneDigits);
  await expect(phoneNumber).toHaveValue(`(${phoneDigits.slice(0, 3)}) ${phoneDigits.slice(3, 6)}-${phoneDigits.slice(6)}`);
  await host.screenshot('phone-typed');
  await host.tap(switcher);
  await expect(identifier).toBeVisible({ timeout: 10_000 });
  await host.tap(switcher);
  await expect(phoneNumber).toBeVisible({ timeout: 10_000 });
  await expect(phoneNumber).toHaveValue('');
  await host.screenshot('phone-cleared');
});
