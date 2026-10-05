import { cpSync, readFileSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { spawn } from 'node:child_process';
import { remoteBackend } from './core/remote/backend.ts';
import { VerifyFailure, type HostAdapter, type NativeHostScreen, type ScratchPath } from './core/types.ts';
import { localIosBackend } from './platform/ios/local.ts';
import { APP_ID, buildHost, builtHost } from './platform/ios/simulator.ts';

const SKILL_DIR = new URL('../', import.meta.url).pathname;
const GITHUB_REPO = 'clerk/clerk-ios';

function pinnedAgentDevice(): string {
  try {
    const mobile = JSON.parse(readFileSync(join(SKILL_DIR, 'node_modules', '@e2e-dev', 'mobile', 'package.json'), 'utf8')) as { dependencies?: Record<string, string> };
    const version = mobile.dependencies?.['agent-device'];
    if (version !== undefined) return version;
  } catch {
    // Falls through to the fix below.
  }
  throw new VerifyFailure('NOT_READY', 'the pinned @e2e-dev/mobile is not installed, so the agent-device version a session needs is unknown', `npm ci --prefix ${SKILL_DIR}`);
}

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
  keysFile: '.keys.json',
  githubRepo: GITHUB_REPO,
  appId: () => APP_ID,
  buildInputs: () => ['Sources', 'Examples/E2EHost', 'Package.swift', 'Package.resolved', 'Clerk.xcworkspace'],
  buildSources: (_platform, os) => (os === 'darwin' ? ['local'] : ['github-actions']),
  async build(platform, source, key, into) {
    if (source !== 'local') throw new VerifyFailure('UNSUPPORTED', `clerk-ios builds only locally for now (asked for ${source})`, 'run {cli} up on a Mac with Xcode');
    const worktree = new URL('../../../../', import.meta.url).pathname;
    const derived = join(into, '..', 'derived');
    const result = await xcodebuild(buildHost(derived).args, worktree);
    if (result.code !== 0) {
      throw new VerifyFailure('BUILD_FAILED', `xcodebuild exited ${result.code}:\n${result.tail}`, 'fix the build error above, then rerun {cli} up');
    }
    const path = join(into, 'E2EHost.app') as ScratchPath;
    rmSync(path, { recursive: true, force: true });
    cpSync(builtHost(derived), path, { recursive: true, verbatimSymlinks: true });
    return { platform, key, appId: APP_ID, path, source, sourceSha: null };
  },
  entry: () => ({ kind: 'binary' }),
  features: ['auth-start', 'sign-in-email-code', 'sign-up', 'user-button-and-profile', 'session-tasks', 'organizations'],
  backends: [
    localIosBackend(),
    remoteBackend({
      platform: 'ios',
      repo: GITHUB_REPO,
      workflow: 'verify-remote.yml',
      sessionsDir: join(SKILL_DIR, '.verify', 'remote'),
      runner: 'blacksmith-6vcpu-macos-27',
      plumbingRunner: 'ubuntu-latest',
      device: 'iPhone Air',
      idleMinutes: 15,
      capMinutes: 60,
      agentDevice: pinnedAgentDevice,
      requirement: 'a pushed branch and access to GitHub Actions on clerk/clerk-ios',
    }),
  ],
};
