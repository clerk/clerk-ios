import { join } from 'node:path';
import type { SessionDeviceFactory } from '../../core/remote/protocol.ts';
import { buildHost, builtHost, installApp, recordVideo, showLogs } from './simulator.ts';

const sessionDevice: SessionDeviceFactory = ({ id: udid }) => ({
  build(work) {
    const derived = join(work, 'derived');
    return [buildHost(derived), { command: 'xcrun', args: ['simctl', 'bootstatus', udid, '-b'] }, installApp(udid, builtHost(derived))];
  },
  record: { start: (file) => recordVideo(udid, file) },
  logs: (since, predicate) => showLogs(udid, since, predicate),
});

export default sessionDevice;
