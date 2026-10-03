import { test, expect } from '../../fixtures.ts';

test('a ticket sign-in with forced organization selection stops on the organization task', async ({ host, screen }) => {
  const user = await host.seedUser({ instance: 'with-session-tasks' });
  const state = await host.launch({ signedInAs: user, screen: 'auth' });
  expect(state.ticket).toBe('succeeded');
  expect(state.sessionStatus).toBe('pending');
  expect(state.pendingTasks).toContain('choose-organization');
  await expect(screen.getByTestId('clerk.organization.profileForm.name')).toBeVisible({ timeout: 20_000 });
  await host.screenshot('choose-organization-task');
});
