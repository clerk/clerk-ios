import type { TestApp } from './support/inputs.ts';

export const APP_ID = 'com.clerk.E2EHost';

export const app: TestApp = {
  platforms: ['ios'],
  id: () => APP_ID,
  entry: () => ({ kind: 'binary' }),
};
