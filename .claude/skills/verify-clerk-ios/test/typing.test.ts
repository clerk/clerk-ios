import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { typeConfirmed, type FocusedField } from '../src/core/typing.ts';

function field(reads: readonly (string | null)[], swallows = 0) {
  const calls: string[] = [];
  let typed = 0;
  let read = 0;
  const fake: FocusedField = {
    async type(text) {
      typed += 1;
      calls.push(typed <= swallows ? `type ${text} (swallowed)` : `type ${text}`);
    },
    async valueIfReadable() {
      calls.push('read');
      const value = reads[Math.min(read, reads.length - 1)]!;
      read += 1;
      return typed <= swallows ? '' : value;
    },
    async refocus() {
      calls.push('refocus');
    },
  };
  return { fake, calls };
}

const settle = { reads: 3, wait: async () => {} };

describe('typeConfirmed', () => {
  it('types once when the field shows the text', async () => {
    const { fake, calls } = field(['Verify']);
    await typeConfirmed(fake, 'Verify', settle);
    assert.deepEqual(calls, ['type Verify', 'read']);
  });

  it('focuses the field and types once more when the field swallowed the first attempt', async () => {
    const { fake, calls } = field(['Verify'], 1);
    await typeConfirmed(fake, 'Verify', settle);
    assert.deepEqual(calls, ['type Verify (swallowed)', 'read', 'read', 'read', 'refocus', 'type Verify', 'read']);
  });

  it('fails and says the text never reached the field when the second attempt is swallowed too', async () => {
    const { fake, calls } = field(['Verify'], 2);
    await assert.rejects(typeConfirmed(fake, 'Verify', settle), /the text never reached the field/);
    assert.equal(calls.filter((call) => call.startsWith('type')).length, 2);
  });

  it('does not type again when the field shows the text a moment after the typing ends', async () => {
    const { fake, calls } = field(['', 'Verify']);
    await typeConfirmed(fake, 'Verify', settle);
    assert.deepEqual(calls, ['type Verify', 'read', 'read']);
  });

  it('types once and confirms nothing when the screen withholds the value, as it does for a secure field', async () => {
    const { fake, calls } = field([null]);
    await typeConfirmed(fake, 'a password', settle);
    assert.deepEqual(calls, ['type a password', 'read']);
  });
});
