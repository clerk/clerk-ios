import { cpSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { spawn } from 'node:child_process';
import { VerifyFailure, type HostAdapter, type NativeHostScreen, type ScratchPath } from './core/types.ts';
import { localIosBackend } from './platform/ios/local.ts';

const APP_ID = 'com.clerk.E2EHost';

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
  platforms: ['ios'],
  screens: ['home', 'auth', 'userProfile', 'orgSwitcher', 'orgList', 'orgProfile'],
  keysFile: '.keys.json',
  githubRepo: 'clerk/clerk-ios',
  appId: () => APP_ID,
  buildInputs: () => ['Sources', 'Examples/E2EHost', 'Package.swift', 'Package.resolved', 'Clerk.xcworkspace'],
  buildSources: (_platform, os) => (os === 'darwin' ? ['local'] : ['github-actions']),
  async build(platform, source, key, into) {
    if (source !== 'local') throw new VerifyFailure('UNSUPPORTED', `clerk-ios builds only locally for now (asked for ${source})`, 'run bin/verify up on a Mac with Xcode');
    const worktree = new URL('../../../../', import.meta.url).pathname;
    const derived = join(into, '..', 'derived');
    const result = await xcodebuild(
      ['build', '-quiet', '-workspace', 'Clerk.xcworkspace', '-scheme', 'E2EHost', '-configuration', 'Debug', '-destination', 'generic/platform=iOS Simulator', '-derivedDataPath', derived],
      worktree,
    );
    if (result.code !== 0) {
      throw new VerifyFailure('BUILD_FAILED', `xcodebuild exited ${result.code}:\n${result.tail}`, 'fix the build error above, then rerun bin/verify up');
    }
    const path = join(into, 'E2EHost.app') as ScratchPath;
    rmSync(path, { recursive: true, force: true });
    cpSync(join(derived, 'Build', 'Products', 'Debug-iphonesimulator', 'E2EHost.app'), path, { recursive: true, verbatimSymlinks: true });
    return { platform, key, appId: APP_ID, path, source, sourceSha: null };
  },
  entry: () => ({ kind: 'binary' }),
  features: ['auth-start', 'sign-in-email-code', 'sign-up', 'user-button-and-profile', 'session-tasks', 'organizations'],
  backends: [localIosBackend()],
};
