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
  const token = process.env.GH_TOKEN || process.env.GITHUB_TOKEN;
  const choice = chooseEgress({
    proxyListens: await accepts(url.hostname, Number(url.port || 80)),
    directConnects: await accepts('api.github.com', 443),
    tokenStatusDirect: token ? await fetch('https://api.github.com/rate_limit', { headers: { Authorization: `Bearer ${token}`, 'User-Agent': 'verify-remote' }, signal: AbortSignal.timeout(5000) }).then((response) => response.status, () => 0) : null,
  });
  process.env.VERIFY_EGRESS_WHY = choice.why;
  if (!choice.proxy) return;
  const local = 'localhost,127.0.0.1,::1';
  const noProxy = process.env.NO_PROXY || process.env.no_proxy;
  process.exit(await rerun(process.execPath, process.argv.slice(1), { ...process.env, NODE_USE_ENV_PROXY: '1', NO_PROXY: noProxy ? `${noProxy},${local}` : local }));
}

/**
 * Node ignores HTTPS_PROXY unless told to honor it, so this decides. A machine that reaches GitHub directly with a
 * token GitHub accepts keeps going direct: that is a Mac with a debugging proxy exported. The proxy is used when the
 * direct path does not work for GitHub: it cannot connect, or GitHub rejects the machine's token on it. The second
 * case is a cloud sandbox, whose token is a placeholder that only its proxy turns into a real credential.
 * `tokenStatusDirect` is null when the environment holds no GitHub token, and 0 when the request failed.
 */
export function chooseEgress({ proxyListens, directConnects, tokenStatusDirect }) {
  if (!proxyListens) return { proxy: false, why: 'HTTPS_PROXY is set but nothing accepts connections there' };
  if (!directConnects || tokenStatusDirect === 0) return { proxy: true, why: 'a direct connection to api.github.com fails' };
  if (tokenStatusDirect === 401) return { proxy: true, why: "GitHub rejects this machine's token on a direct connection, so the proxy is where the real credential is added" };
  return { proxy: false, why: tokenStatusDirect === null ? 'a direct connection to api.github.com works' : 'a direct connection to api.github.com works and GitHub accepts the token on it' };
}
