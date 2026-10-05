import { join } from 'node:path';
import type { CommandLine } from '../../core/exec.ts';

/** The simulator commands the local backend and a remote session both run, so the two cannot drift. */

export const APP_ID = 'com.clerk.E2EHost';

const LOG_PREDICATE = 'subsystem == "com.clerk.verify" OR subsystem == "com.clerk.sdk"';

function localTime(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

export const buildHost = (derived: string): CommandLine => ({
  command: 'xcodebuild',
  args: ['build', '-quiet', '-workspace', 'Clerk.xcworkspace', '-scheme', 'E2EHost', '-configuration', 'Debug', '-destination', 'generic/platform=iOS Simulator', '-derivedDataPath', derived],
});

export const builtHost = (derived: string): string => join(derived, 'Build', 'Products', 'Debug-iphonesimulator', 'E2EHost.app');

export const installApp = (udid: string, app: string): CommandLine => ({ command: 'xcrun', args: ['simctl', 'install', udid, app] });

export const recordVideo = (udid: string, file: string): CommandLine => ({ command: 'xcrun', args: ['simctl', 'io', udid, 'recordVideo', '--codec=h264', '--force', file] });

export const showLogs = (udid: string, since: Date, extraPredicate: string | null): CommandLine => ({
  command: 'xcrun',
  args: ['simctl', 'spawn', udid, 'log', 'show', '--style', 'compact', '--start', localTime(since), '--predicate', extraPredicate === null ? LOG_PREDICATE : `${LOG_PREDICATE} OR (${extraPredicate})`],
});
