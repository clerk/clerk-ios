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

  it('confirms what it typed against the text input that had focus before the typing, and treats a value the screen withholds as unreadable', () => {
    const source = readFileSync(join(import.meta.dirname, '..', 'specs', 'fixtures.ts'), 'utf8');
    assert.match(source, /const focused = device\.locator\('role=textbox focused'\);/);
    assert.match(source, /const now = await frame\(\)\.catch\(\(\) => null\);\n\s+if \(input === null \|\| now === null \|\| now\.x !== input\.x \|\| now\.y !== input\.y \|\| now\.width !== input\.width \|\| now\.height !== input\.height\) return null;\n\s+return focused\.inputValue\(\)\.catch\(\(\) => null\);/, 'a focused input at another place is another field, and typing into it again would be wrong');
  });
});
