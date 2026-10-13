import { test, expect } from '../../fixtures.ts';

test('a session survives a relaunch of the app', async ({ host }) => {
  const user = await host.seedUser();
  await host.launch({ signedInAs: user });
  const sessionId = (await host.app.sessionId.textContent()) ?? '';
  expect(sessionId).not.toBe('');
  await host.launch({ keepStorage: true, landsOn: host.app.signedIn });
  await host.expectSignedInAs(user);
  await expect(host.app.sessionId).toHaveText(sessionId);
  await host.screenshot('relaunched');
});
