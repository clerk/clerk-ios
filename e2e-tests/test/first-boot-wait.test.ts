import '@clerk/internal-mobile-e2e/testing/git-env';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, it } from 'node:test';

const workflow = readFileSync(join(import.meta.dirname, '..', '..', '.github', 'workflows', 'verify-e2e.yml'), 'utf8');

describe('the workflow step that waits for the first-boot work of the simulator', () => {
  const lines = workflow.split('\n').map((line) => line.trim());
  const step = lines.indexOf('- name: Wait for the simulator to finish its first-boot work');
  const first = lines.findIndex((line, at) => at > step && line.startsWith('limit='));
  const last = lines.findIndex((line, at) => at > first && line.startsWith('[ "$load" -lt "$limit" ] ||'));
  const wait = lines.slice(first, last + 1).join('\n');

  function waited(cores: number, loads: readonly number[]): { status: number | null; stdout: string; sleeps: number } {
    const work = mkdtempSync(join(tmpdir(), 'verify-first-boot-wait-'));
    mkdirSync(join(work, 'bin'));
    writeFileSync(join(work, 'loads'), `${loads.join('\n')}\n`);
    writeFileSync(join(work, 'asked'), '');
    writeFileSync(join(work, 'slept'), '');
    writeFileSync(
      join(work, 'bin', 'sysctl'),
      `#!/bin/sh
if [ "$2" = hw.ncpu ]; then echo ${cores}; exit 0; fi
echo x >> "${work}/asked"
at=$(wc -l < "${work}/asked")
all=$(wc -l < "${work}/loads")
[ "$at" -gt "$all" ] && at=$all
echo "{ $(sed -n "\${at}p" "${work}/loads").42 9.99 9.99 }"
`,
      { mode: 0o755 },
    );
    writeFileSync(join(work, 'bin', 'sleep'), `#!/bin/sh\necho "$1" >> "${work}/slept"\n`, { mode: 0o755 });
    const ran = spawnSync('bash', ['-e', '-c', wait], { env: { PATH: `${join(work, 'bin')}:${process.env.PATH}` }, encoding: 'utf8', timeout: 60_000 });
    const sleeps = readFileSync(join(work, 'slept'), 'utf8').split('\n').filter((line) => line === '5').length;
    rmSync(work, { recursive: true, force: true });
    return { status: ran.status, stdout: ran.stdout, sleeps };
  }

  it('starts the tests at once on a runner that is already quiet', () => {
    assert.ok(step > 0 && first > step && last > first, 'the wait loop is in the workflow');
    assert.deepEqual(waited(3, [14]), { status: 0, stdout: 'the 1-minute load average is 14 after 0 seconds, and the tests start below 60\n', sleeps: 0 });
  });

  it('waits until the load average is below 20 for each core', () => {
    assert.deepEqual(waited(3, [640, 301, 61, 60, 59]), { status: 0, stdout: 'the 1-minute load average is 59 after 20 seconds, and the tests start below 60\n', sleeps: 4 });
    assert.deepEqual(waited(6, [640, 119]), { status: 0, stdout: 'the 1-minute load average is 119 after 5 seconds, and the tests start below 120\n', sleeps: 1 });
  });

  it('starts the tests with a warning when the load average stays high for 12 minutes', () => {
    assert.deepEqual(waited(3, [500]), {
      status: 0,
      stdout:
        'the 1-minute load average is 500 after 720 seconds, and the tests start below 60\n::warning::the first-boot work of the simulator had not ended after 12 minutes; the tests start anyway\n',
      sleeps: 145,
    });
  });
});
