import { cpSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { run } from './core/exec.ts';
import { remoteBackend } from './core/remote/backend.ts';
import { VerifyFailure, type HostAdapter, type ScratchPath } from './core/types.ts';
import { localIosBackend } from './platform/ios/local.ts';
import { APP_ID, BUILD_HOST, builtHost } from './host-app.ts';

const SKILL_DIR = fileURLToPath(new URL('../', import.meta.url));
const WORKTREE = fileURLToPath(new URL('../../../../', import.meta.url));
const GITHUB_REPO = 'clerk/clerk-ios';

export const host: HostAdapter = {
  repo: 'clerk-ios',
  cli: '.claude/skills/verify-clerk-ios/bin/control-clerk-ios',
  platforms: ['ios'],
  githubRepo: GITHUB_REPO,
  appId: () => APP_ID,
  buildInputs: () => ['Sources', 'Examples/E2EHost', 'Examples/Quickstart/Quickstart.xcodeproj', 'Package.swift', 'Clerk.xcworkspace'],
  async build(platform, key, into) {
    const derived = join(into, '..', 'derived');
    const result = await run('xcodebuild', [...BUILD_HOST, derived], { cwd: WORKTREE });
    if (result.code !== 0) {
      const tail = `${result.stdout}\n${result.stderr}`.split('\n').filter((line) => line.trim().length > 0).slice(-15).join('\n');
      throw new VerifyFailure('BUILD_FAILED', `xcodebuild exited ${result.code}:\n${tail}`, 'fix the build error above, then rerun {cli} up');
    }
    const path = join(into, 'E2EHost.app') as ScratchPath;
    rmSync(path, { recursive: true, force: true });
    cpSync(builtHost(derived), path, { recursive: true, verbatimSymlinks: true });
    return { platform, key, appId: APP_ID, path, source: 'local' };
  },
  entry: () => ({ kind: 'binary' }),
  backends: [
    localIosBackend(),
    remoteBackend({
      platform: 'ios',
      repo: GITHUB_REPO,
      workflow: 'verify-remote.yml',
      sessionsDir: join(SKILL_DIR, '.verify', 'remote'),
      runner: 'xcode-27',
      plumbingRunner: 'ubuntu-latest',
      device: 'iPhone Air',
      idleMinutes: 15,
      capMinutes: 60,
      requirement: 'a pushed branch and access to GitHub Actions on clerk/clerk-ios',
    }),
  ],
};
