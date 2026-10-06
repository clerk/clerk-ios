import { cpSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { VerifyFailure, type HostAdapter, type NativeHostScreen, type ScratchPath } from './core/types.ts';
import { localIosBackend } from './platform/ios/local.ts';
import { APP_ID, buildHost, builtHost } from './host-app.ts';

const WORKTREE = fileURLToPath(new URL('../../../../', import.meta.url));
const GITHUB_REPO = 'clerk/clerk-ios';

function xcodebuild(args: readonly string[], cwd: string): Promise<{ code: number; tail: string }> {
  return new Promise((resolve) => {
    const child = spawn('xcodebuild', [...args], { cwd, stdio: ['ignore', 'pipe', 'pipe'] });
    const lines: string[] = [];
    const collect = (chunk: Buffer) => {
      for (const line of chunk.toString().split('\n')) {
        if (line.trim().length === 0) continue;
        lines.push(line);
        if (lines.length > 40) lines.shift();
      }
    };
    child.stdout.on('data', collect);
    child.stderr.on('data', collect);
    child.on('error', () => resolve({ code: 127, tail: 'xcodebuild could not start' }));
    child.on('close', (code) => resolve({ code: code ?? 1, tail: lines.slice(-15).join('\n') }));
  });
}

export const host: HostAdapter<NativeHostScreen> = {
  repo: 'clerk-ios',
  cli: '.claude/skills/verify-clerk-ios/bin/control-clerk-ios',
  platforms: ['ios'],
  screens: ['home', 'auth', 'userProfile', 'orgSwitcher', 'orgList', 'orgProfile'],
  githubRepo: GITHUB_REPO,
  appId: () => APP_ID,
  buildInputs: () => ['Sources', 'Examples/E2EHost', 'Package.swift', 'Clerk.xcworkspace'],
  async build(platform, key, into) {
    const derived = join(into, '..', 'derived');
    const result = await xcodebuild(buildHost(derived).args, WORKTREE);
    if (result.code !== 0) {
      throw new VerifyFailure('BUILD_FAILED', `xcodebuild exited ${result.code}:\n${result.tail}`, 'fix the build error above, then rerun {cli} up');
    }
    const path = join(into, 'E2EHost.app') as ScratchPath;
    rmSync(path, { recursive: true, force: true });
    cpSync(builtHost(derived), path, { recursive: true, verbatimSymlinks: true });
    return { platform, key, appId: APP_ID, path, source: 'local' };
  },
  entry: () => ({ kind: 'binary' }),
  features: ['auth-start', 'sign-in-email-code', 'sign-up', 'user-button-and-profile', 'session-tasks', 'organizations'],
  backends: [
    localIosBackend(),
  ],
};
