import { spawn, spawnSync } from 'node:child_process';
import net from 'node:net';

// Plain JavaScript that any Node can parse, because it is what gets an old Node out of the way before any TypeScript loads.

function rerun(command, args, env) {
  return new Promise((resolve) => {
    const child = spawn(command, args, { stdio: 'inherit', env });
    // A killed wrapper must take the real CLI with it, or that CLI keeps polling, and so keeps alive, a billed session.
    for (const signal of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.on(signal, () => child.kill(signal));
    child.on('error', () => resolve(127));
    child.on('close', (code, signal) => resolve(code ?? (signal === null ? 1 : 130)));
  });
}

function accepts(host, port) {
  return new Promise((resolve) => {
    const socket = net.connect({ host, port, timeout: 1500 });
    const done = (ok) => {
      socket.destroy();
      resolve(ok);
    };
    socket.on('connect', () => done(true));
    socket.on('timeout', () => done(false));
    socket.on('error', () => done(false));
  });
}

/** Returns once this process is Node 24 with its proxy settings in effect. Otherwise it reruns the CLI and exits. */
export async function ensureRuntime() {
  if (Number(process.versions.node.split('.')[0]) !== 24) {
    // A cloud sandbox often ships an older Node. npx fetches Node 24 from the npm registry and puts it first on PATH,
    // so e2e and agent-device, which this CLI starts, run on it too.
    if (process.env.VERIFY_NODE_RERUN === undefined && /^v24\./.test(spawnSync('npx', ['-y', 'node@24', '--version'], { encoding: 'utf8' }).stdout ?? '')) {
      console.error(`note  this is Node ${process.versions.node}; running under node@24 through npx`);
      process.exit(await rerun('npx', ['-y', 'node@24', ...process.argv.slice(1)], { ...process.env, VERIFY_NODE_RERUN: '1' }));
    }
    const message = `this CLI needs Node 24 and this is Node ${process.versions.node}; npx could not fetch node@24`;
    const fix = 'install Node 24 (nvm install 24 && nvm use 24) and rerun';
    if (process.argv.includes('--json')) console.log(JSON.stringify({ ok: false, error: { code: 'NOT_READY', message, fix, retryable: false } }));
    else console.error(`FAIL  node  ${message}\n      fix: ${fix}`);
    process.exit(3);
  }

  const proxy = process.env.HTTPS_PROXY || process.env.https_proxy;
  if (!proxy || process.env.NODE_USE_ENV_PROXY !== undefined) return;
  let url;
  try {
    url = new URL(proxy);
  } catch {
    return;
  }
  // Node ignores HTTPS_PROXY unless told to honor it, and a sandbox's proxy is its only way out and the place its
  // GitHub credentials are added. A proxy that is not listening (a debugging proxy that is closed) is skipped.
  if (!(await accepts(url.hostname, Number(url.port || 80)))) return;
  const local = 'localhost,127.0.0.1,::1';
  const noProxy = process.env.NO_PROXY || process.env.no_proxy;
  process.exit(await rerun(process.execPath, process.argv.slice(1), { ...process.env, NODE_USE_ENV_PROXY: '1', NO_PROXY: noProxy ? `${noProxy},${local}` : local }));
}
