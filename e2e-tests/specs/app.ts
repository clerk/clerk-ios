import type { TestApp } from '@clerk/internal-mobile-e2e/specs/support/inputs';

export const APP_ID = 'com.clerk.E2EHost';

export const app: TestApp = {
  platforms: ['ios'],
  id: () => APP_ID,
  entry: () => ({ kind: 'binary' }),
};
