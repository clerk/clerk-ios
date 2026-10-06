import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';
import { describe, it } from 'node:test';

describe('specs/fixtures.ts', () => {
  it('names no host-specific screen union, and takes its screens from the host it imports', () => {
    const source = readFileSync(join(import.meta.dirname, '..', 'specs', 'fixtures.ts'), 'utf8');
    for (const union of ['NativeHostScreen', 'ExpoHostScreen']) assert.equal(source.includes(union), false, `fixtures.ts names ${union}`);
    assert.match(source, /import type \{ host as hostAdapter \} from '\.\.\/src\/host\.ts';/);
  });

  it('taps with a plain locator tap, and fills by tapping the field and typing into the focused input, because a field can show no text input until it has focus', () => {
    const source = readFileSync(join(import.meta.dirname, '..', 'specs', 'fixtures.ts'), 'utf8');
    assert.match(source, /tap: \(target\) => target\.tap\(\{ timeout: ASSERTION_TIMEOUT_MS \}\),/);
    assert.doesNotMatch(source, /position:/);
    assert.match(source, /async fill\(field, text\) \{\n\s+await host\.tap\(field\);/);
    assert.doesNotMatch(source, /\.fill\(/);
  });
});
