import { fileURLToPath } from 'node:url';
import type { SessionDeviceFactory } from '../../core/remote/protocol.ts';
import { recordVideo, showLogs } from './simulator.ts';

const SESSION_BUILD = fileURLToPath(new URL('./session-build.ts', import.meta.url));
const WORKTREE = fileURLToPath(new URL('../../../../', import.meta.url));

const sessionDevice: SessionDeviceFactory = ({ id: udid }) => ({
  build: (work) => [{ command: process.execPath, args: [SESSION_BUILD, 'build', work, udid], cwd: WORKTREE }],
  record: { start: (file) => recordVideo(udid, file) },
  logs: (since, predicate) => showLogs(udid, since, predicate),
});

export default sessionDevice;
