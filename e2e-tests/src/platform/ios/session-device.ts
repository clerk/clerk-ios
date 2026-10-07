import { join } from 'node:path';
import type { SessionDeviceFactory } from '../../core/remote/protocol.ts';
import { buildHost, builtHost } from '../../host-app.ts';
import { installApp, recordVideo, showLogs, waitForBoot } from './simulator.ts';

const sessionDevice: SessionDeviceFactory = ({ id: udid }) => ({
  build(work) {
    const derived = join(work, 'derived');
    return [buildHost(derived), waitForBoot(udid), installApp(udid, builtHost(derived))];
  },
  record: { start: (file) => recordVideo(udid, file) },
  logs: (since, predicate) => showLogs(udid, since, predicate),
});

export default sessionDevice;
