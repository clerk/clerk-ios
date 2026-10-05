import { join } from 'node:path';
import type { SessionDeviceFactory } from '../src/core/remote/protocol.ts';

const node = process.execPath;
const fake: SessionDeviceFactory = (deviceId) => ({
  build: (work) => [{ command: node, args: ['-e', `require('fs').writeFileSync(${JSON.stringify(join(work, 'built'))}, require('fs').readFileSync('app.txt', 'utf8'))`] }],
  record: { start: (file) => ({ command: node, args: ['-e', `process.on('SIGINT', () => { require('fs').writeFileSync(${JSON.stringify(file)}, 'video of ${deviceId}'); process.exit(0); }); setInterval(() => {}, 1000)`] }) },
  logs: (_since, predicate) => ({ command: node, args: ['-e', `console.log('log line for ${deviceId} ${predicate ?? ''}')`] }),
});
export default fake;
