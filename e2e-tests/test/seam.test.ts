import assert from 'node:assert/strict';
import { join } from 'node:path';
import { describe, it } from 'node:test';
import { pathsThatLeaveTheTests } from '@clerk/internal-mobile-e2e/testing/seam';

describe('the tests are an e2e project of their own', () => {
  it('keeps specs/ and e2e.config.ts from importing files outside specs/', () => {
    assert.deepEqual(pathsThatLeaveTheTests(join(import.meta.dirname, '..')), []);
  });
});
