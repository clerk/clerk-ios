#!/usr/bin/env node

import { execFileSync, spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join, relative } from 'node:path';

const input = JSON.parse(readFileSync(0, 'utf8'));
const file = input.tool_input?.file_path;

if (!file?.endsWith('.swift') || !existsSync(file)) process.exit(0);

let root;
try {
  root = execFileSync('git', ['-C', dirname(file), 'rev-parse', '--show-toplevel'], {
    encoding: 'utf8',
    stdio: ['ignore', 'pipe', 'ignore'],
  }).trim();
} catch {
  process.exit(0);
}

const swiftformat = join(root, '.tools/bin/swiftformat');
const swiftlint = join(root, '.tools/bin/swiftlint');
if (!existsSync(swiftformat) || !existsSync(swiftlint)) process.exit(0);

const path = relative(root, file);
const run = (bin, args) => spawnSync(bin, args, { cwd: root, encoding: 'utf8' });

const format = run(swiftformat, ['--quiet', path]);
if (format.status !== 0) {
  process.stderr.write(`SwiftFormat could not format ${path}:\n${format.stderr}`);
  process.exit(2);
}

run(swiftlint, ['--fix', '--quiet', '--force-exclude', path]);

const lint = run(swiftlint, ['lint', '--quiet', '--force-exclude', path]);
const errors = lint.stdout.split('\n').filter((line) => line.includes(': error: '));
if (errors.length > 0) {
  process.stderr.write(`SwiftLint errors in ${path} that --fix could not fix:\n${errors.join('\n')}\n`);
  process.exit(2);
}
