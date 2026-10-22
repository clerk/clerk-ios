import type { TestPhone } from '@clerk/internal-mobile-e2e/specs/support/types';

export const asShownByClerk = (phone: TestPhone): string => `+1 (${phone.slice(2, 5)}) ${phone.slice(5, 8)}‑${phone.slice(8)}`;
