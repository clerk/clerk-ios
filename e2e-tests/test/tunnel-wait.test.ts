import '../testing/git-env.ts';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { describe, it } from 'node:test';

const workflow = readFileSync(join(import.meta.dirname, '..', '..', '.github', 'workflows', 'verify-remote.yml'), 'utf8');

describe('the workflow step that waits for the tunnel', () => {
  const lines = workflow.split('\n').map((line) => line.trim());
  const step = lines.indexOf('- name: Start the session agent and tunnel');
  const first = lines.findIndex((line, at) => at > step && /^for _ in \$\(seq 1 \d+\); do$/.test(line));
  const last = lines.findIndex((line, at) => at > first && line.startsWith('[ -s "$WORK/tunnel" ] ||'));
  const wait = lines.slice(first, last + 1).join('\n');

  function waited(agent: 'running' | 'gone', tunnel: 'published' | 'none'): { status: number | null; stdout: string } {
    const work = mkdtempSync(join(tmpdir(), 'verify-tunnel-wait-'));
    mkdirSync(join(work, 'bin'));
    writeFileSync(join(work, 'bin', 'pgrep'), `#!/bin/sh\nexit ${agent === 'running' ? 0 : 1}\n`, { mode: 0o755 });
    if (tunnel === 'published') writeFileSync(join(work, 'tunnel'), 'quick-fox.trycloudflare.com');
    writeFileSync(join(work, 'agent.log'), 'verify-remote session ios0000aa on :3199\n');
    writeFileSync(join(work, 'tunnel.log'), 'failed to request quick Tunnel\n');
    const ran = spawnSync('bash', ['-c', wait], { env: { PATH: `${join(work, 'bin')}:${process.env.PATH}`, WORK: work }, encoding: 'utf8', timeout: 20_000 });
    rmSync(work, { recursive: true, force: true });
    return { status: ran.status, stdout: ran.stdout };
  }

  it('fails within seconds, with both logs, when the agent has ended and no tunnel came up', () => {
    assert.ok(step > 0 && first > step && last > first, 'the wait loop is in the workflow');
    const { status, stdout } = waited('gone', 'none');
    assert.equal(status, 1);
    assert.ok(stdout.startsWith('::error::the session agent ended before a tunnel came up\n::error::no tunnel came up\n'), stdout);
    assert.ok(stdout.includes('verify-remote session ios0000aa on :3199'), stdout);
    assert.ok(stdout.includes('failed to request quick Tunnel'), stdout);
  });

  it('does not take the agent for ended while its process is still starting', () => {
    const work = mkdtempSync(join(tmpdir(), 'verify-tunnel-start-'));
    mkdirSync(join(work, 'bin'));
    writeFileSync(join(work, 'started'), String(Date.now()));
    writeFileSync(join(work, 'bin', 'pgrep'), `#!${process.execPath}\nconst fs = require('fs');\nif (Date.now() - Number(fs.readFileSync('${join(work, 'started')}', 'utf8')) < 500) process.exit(1);\nfs.writeFileSync('${join(work, 'tunnel')}', 'quick-fox.trycloudflare.com');\n`, { mode: 0o755 });
    const ran = spawnSync('bash', ['-c', wait], { env: { PATH: `${join(work, 'bin')}:${process.env.PATH}`, WORK: work }, encoding: 'utf8', timeout: 20_000 });
    rmSync(work, { recursive: true, force: true });
    assert.deepEqual({ status: ran.status, stdout: ran.stdout }, { status: 0, stdout: '' });
  });

  it('goes on as soon as the tunnel is published', () => {
    assert.deepEqual(waited('running', 'published'), { status: 0, stdout: '' });
  });
});
