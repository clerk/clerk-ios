import { createHmac } from 'node:crypto';
import { test, expect } from '../../fixtures.ts';

function totp(base32Secret: string, unixSeconds: number): string {
  const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  let bits = '';
  for (const char of base32Secret.toUpperCase().replace(/[^A-Z2-7]/g, '')) {
    bits += alphabet.indexOf(char).toString(2).padStart(5, '0');
  }
  const key = Buffer.from((bits.match(/.{8}/g) ?? []).map((byte) => parseInt(byte, 2)));
  const counter = Buffer.alloc(8);
  counter.writeBigUInt64BE(BigInt(Math.floor(unixSeconds / 30)));
  const digest = createHmac('sha1', key).update(counter).digest();
  const offset = digest[digest.length - 1]! & 0x0f;
  return String((digest.readUInt32BE(offset) & 0x7fffffff) % 1_000_000).padStart(6, '0');
}

test('enrolls an authenticator app to finish the setup-MFA task', { tags: ['form-entry'] }, async ({ host, screen }) => {
  const user = await host.seedUser({ instance: 'with-session-tasks-setup-mfa' });
  const state = await host.launch({ signedInAs: user, screen: 'auth' });
  expect(state.pendingTasks).toContain('setup-mfa');
  await host.tap(screen.getByTestId('clerk.auth.sessionTask.setupMfa.authenticatorApp'));
  const secret = screen.getByTestId('clerk.auth.sessionTask.totp.secret');
  await expect(secret).toBeVisible({ timeout: 20_000 });
  const secretText = (await secret.textContent()) ?? '';
  await host.screenshot('totp-secret');
  await host.tap(screen.getByTestId('clerk.auth.sessionTask.totp.continue'));
  await host.fill(screen.getByTestId('clerk.auth.sessionTask.totp.code'), totp(secretText, Date.now() / 1000));
  const backupCodesContinue = screen.getByTestId('clerk.auth.sessionTask.backupCodes.continue');
  await screen.scrollUntilVisible(backupCodesContinue);
  await host.tap(backupCodesContinue);
  const done = await host.waitForState((s) => s.sessionStatus === 'active', 30_000);
  expect(done.pendingTasks).toEqual([]);
  expect(done.userId).toBe(user.id);
});
