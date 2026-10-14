import { test, expect } from '../../fixtures.ts';
import { totp } from '../../totp.ts';

test('enrolls an authenticator app to finish the setup-MFA task', async ({ host, screen }) => {
  const user = await host.seedUser();
  const authenticatorApp = screen.getByTestId('clerk.auth.sessionTask.setupMfa.authenticatorApp');
  await host.launch({ signedInAs: user, landsOn: host.app.signedOut });
  await host.tap(host.app.signInFullScreen);
  await expect(authenticatorApp).toBeVisible({ timeout: 20_000 });
  await expect(screen.getByTestId('clerk.auth.sessionTask.setupMfa.smsCode')).toBeVisible();
  await host.screenshot('session-task-before-totp');
  await host.tap(authenticatorApp);
  const secret = screen.getByTestId('clerk.auth.sessionTask.totp.secret');
  await expect(secret).toBeVisible({ timeout: 20_000 });
  const secretText = (await secret.textContent()) ?? '';
  await host.screenshot('totp-secret');
  await host.tap(screen.getByTestId('clerk.auth.sessionTask.totp.continue'));
  await host.fill(screen.getByTestId('clerk.auth.sessionTask.totp.code'), totp(secretText, Date.now() / 1000));
  const backupCodesContinue = screen.getByTestId('clerk.auth.sessionTask.backupCodes.continue');
  await screen.scrollUntilVisible(backupCodesContinue);
  await host.tap(backupCodesContinue);
  await host.expectSignedInAs(user, 30_000);
  await host.screenshot('task-complete');
});
