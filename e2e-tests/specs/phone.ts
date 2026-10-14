import type { TestPhone } from './support/types.ts';

export const asShownByClerk = (phone: TestPhone): string => `+1 (${phone.slice(2, 5)}) ${phone.slice(5, 8)}‑${phone.slice(8)}`;
