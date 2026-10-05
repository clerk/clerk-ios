import { spawn, type ChildProcess } from 'node:child_process';
import { Resolver } from 'node:dns/promises';
import { appendFileSync, createReadStream, existsSync, mkdirSync, rmSync, statSync, writeFileSync } from 'node:fs';
import http, { type IncomingMessage, type ServerResponse } from 'node:http';
import net from 'node:net';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import {
  RequestError,
  matchesToken,
  parseRequest,
  probeEcho,
  type BuildState,
  type EndReason,
  type SessionDevice,
  type SessionDeviceFactory,
  type SessionHealth,
  type SessionRequest,
} from './protocol.ts';
import type { CommandLine } from '../exec.ts';
import { TUNNEL } from './tunnel.ts';

/**
 * The only thing a session's tunnel exposes. It ends the session itself when the driver goes silent or the cap
 * passes, because a held runner bills by the minute and a crashed driver cannot call stop.
 */

const AGENT_ROUTES = ['/agent-device', '/health', '/rpc', '/upload', '/artifacts'];
const RUNNER_LOGS = ['agent-device-proxy', 'build', 'tunnel'] as const;
const DAEMON_GRACE_MS = 60_000;
const COMMAND_TIMEOUT_MS = 30_000;
const BUILD_TIMEOUT_MINUTES = 30;

function setOutputs(file: string | undefined, values: Readonly<Record<string, string>>): void {
  const text = Object.entries(values).map(([key, value]) => `${key}=${value}\n`).join('');
  if (file === undefined || file === '') process.stdout.write(text);
  else appendFileSync(file, text);
}

/** The plan job: turns either trigger's payload into validated job outputs, or `mode=none` for anything else. */
export function plan(env: Readonly<Record<string, string | undefined>> = process.env): void {
  let request: SessionRequest;
  try {
    request = parseRequest((env.VERIFY_REQUEST ?? '').trim());
  } catch (error) {
    if (!(error instanceof RequestError)) throw error;
    console.log(`::notice title=verify-remote::no session started: ${error.message}`);
    setOutputs(env.GITHUB_OUTPUT, { mode: 'none' });
    return;
  }
  setOutputs(env.GITHUB_OUTPUT, {
    mode: request.mode,
    runner: request.runner,
    session: request.session,
    platform: request.platform,
    device: request.device ?? '',
    sha: request.sha ?? '',
    timeout: String(request.capMinutes + 10),
    agent_device: request.agentDevice,
    echo: probeEcho(request),
    request: JSON.stringify(request),
  });
}

function json(res: ServerResponse, status: number, body: unknown): void {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(body));
}

function bearer(req: IncomingMessage): string | null {
  return /^Bearer\s+(.+)$/i.exec((req.headers.authorization ?? '').trim())?.[1] ?? null;
}

const isAgentRoute = (pathname: string): boolean => AGENT_ROUTES.some((route) => pathname === route || pathname.startsWith(`${route}/`));

function exitOf(child: ChildProcess): Promise<number> {
  return new Promise((done) => {
    child.on('error', () => done(127));
    child.on('close', (code) => done(code ?? 1));
  });
}

/** Build tools start children of their own, so a build runs in its own process group and is stopped as a group. */
function stopGroup(child: ChildProcess | null): void {
  if (child?.pid === undefined || child.exitCode !== null) return;
  const signal = (name: NodeJS.Signals) => {
    try {
      process.kill(-child.pid!, name);
    } catch {
      child.kill(name);
    }
  };
  signal('SIGTERM');
  setTimeout(() => child.exitCode === null && signal('SIGKILL'), 10_000).unref();
}

async function runBriefly(commands: readonly CommandLine[]): Promise<void> {
  for (const step of commands) {
    const child = spawn(step.command, [...step.args], { cwd: step.cwd, stdio: 'ignore' });
    const timer = setTimeout(() => child.kill('SIGKILL'), COMMAND_TIMEOUT_MS);
    await exitOf(child);
    clearTimeout(timer);
  }
}

export async function serve(env: Readonly<Record<string, string | undefined>> = process.env): Promise<void> {
  const request = parseRequest(env.VERIFY_SESSION_REQUEST ?? '');
  const work = resolve(env.VERIFY_SESSION_WORK ?? 'verify-remote-work');
  const port = Number(env.VERIFY_SESSION_PORT ?? 3199);
  const agentPort = Number(env.VERIFY_SESSION_AGENT_PORT ?? 4310);
  const deviceId = env.VERIFY_SESSION_DEVICE_ID ?? '';
  const deviceName = env.VERIFY_SESSION_DEVICE_NAME ?? deviceId;
  mkdirSync(work, { recursive: true });

  let device: SessionDevice | null = null;
  if (deviceId !== '') {
    const module = (await import(pathToFileURL(resolve(env.VERIFY_SESSION_DEVICE_MODULE ?? '')).href)) as { default: SessionDeviceFactory };
    device = module.default(deviceId);
  }

  /** Tests shorten the minute so idle stop and the cap can be watched without waiting for them. */
  const minuteMs = Number(env.VERIFY_SESSION_MINUTE_MS ?? 60_000);
  const tickMs = Math.min(5000, minuteMs / 6);
  const startedAt = Date.now();
  const capAt = startedAt + request.capMinutes * minuteMs;
  const idleMs = request.idleMinutes * minuteMs;
  let lastDriverAt = startedAt;
  let token: string | null = null;
  let ending: EndReason | null = null;
  let daemonOkAt = 0;
  let proxy: ChildProcess | null = null;
  let proxyStartedAt = 0;
  let recorder: { readonly child: ChildProcess; readonly exited: Promise<number>; readonly file: string } | null = null;
  let build: BuildState = { state: 'none' };
  let buildChild: ChildProcess | null = null;
  let buildGeneration = 0;
  let buildSettled: Promise<unknown> = Promise.resolve();
  let buildBegan = 0;
  let builtOnce = false;

  const logFile = (name: (typeof RUNNER_LOGS)[number]) => join(work, `${name}.log`);
  const scrub = (text: string): string => (token === null ? text : text.split(token).join('<token>'));
  const log = (name: (typeof RUNNER_LOGS)[number], chunk: Buffer | string): void => appendFileSync(logFile(name), scrub(chunk.toString()));

  const tunnel = spawn(env.VERIFY_SESSION_CLOUDFLARED ?? TUNNEL.binary, [...TUNNEL.command(port)], { stdio: ['ignore', 'pipe', 'pipe'] });
  let tunnelSeen = '';
  let tunnelHost: string | null = null;
  /**
   * A new tunnel name does not resolve for some seconds, and a machine that asks too early caches the miss, for
   * minutes on macOS. So the name is published only once public resolvers have it, asked directly so that this
   * machine's own cache never sees the miss either.
   */
  async function publishTunnel(host: string): Promise<void> {
    const resolver = new Resolver({ timeout: 2000, tries: 1 });
    resolver.setServers(['1.1.1.1', '8.8.8.8']);
    const deadline = Date.now() + (env.VERIFY_SESSION_SKIP_DNS === '1' ? 0 : 90_000);
    while (Date.now() < deadline) {
      if (await resolver.resolve4(host).then((found) => found.length > 0, () => false)) break;
      await new Promise((done) => setTimeout(done, 1000));
    }
    writeFileSync(join(work, 'tunnel'), host);
  }
  const onTunnel = (chunk: Buffer) => {
    log('tunnel', chunk);
    if (tunnelHost !== null) return;
    tunnelSeen += chunk.toString();
    tunnelHost = TUNNEL.hostPattern.exec(tunnelSeen)?.[1] ?? null;
    if (tunnelHost !== null) void publishTunnel(tunnelHost);
  };
  tunnel.stdout.on('data', onTunnel);
  tunnel.stderr.on('data', onTunnel);
  void exitOf(tunnel).then(() => end('tunnel-lost'));

  function ensureProxy(): void {
    if (token === null || proxy !== null || ending !== null) return;
    const child = spawn('agent-device', ['proxy', '--host', '127.0.0.1', '--port', String(agentPort)], {
      env: { ...process.env, AGENT_DEVICE_DAEMON_AUTH_TOKEN: token },
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    proxy = child;
    proxyStartedAt = Date.now();
    child.stdout.on('data', (chunk: Buffer) => log('agent-device-proxy', chunk));
    child.stderr.on('data', (chunk: Buffer) => log('agent-device-proxy', chunk));
    void exitOf(child).then(() => {
      if (proxy === child) proxy = null;
    });
  }

  async function checkDaemon(): Promise<void> {
    if (proxy === null) return;
    try {
      const response = await fetch(`http://127.0.0.1:${agentPort}/health`, { signal: AbortSignal.timeout(4000) });
      if (response.ok && /"ok":\s*true/.test(await response.text())) daemonOkAt = Date.now();
    } catch {
      // An unreachable proxy is handled below by age.
    }
    if (Date.now() - Math.max(daemonOkAt, proxyStartedAt) > DAEMON_GRACE_MS) proxy.kill('SIGTERM');
  }

  function runCommands(commands: readonly CommandLine[], generation: number, tail: string[]): Promise<number> {
    return commands.reduce<Promise<number>>(async (previous, step) => {
      const code = await previous;
      if (code !== 0 || generation !== buildGeneration) return code === 0 ? 1 : code;
      log('build', `\n$ ${step.command} ${step.args.join(' ')}\n`);
      const child = spawn(step.command, [...step.args], { cwd: step.cwd, stdio: ['ignore', 'pipe', 'pipe'], detached: true });
      buildChild = child;
      const collect = (chunk: Buffer) => {
        log('build', chunk);
        for (const line of chunk.toString().split('\n')) if (line.trim() !== '') tail.push(line);
        tail.splice(0, Math.max(0, tail.length - 30));
      };
      child.stdout.on('data', collect);
      child.stderr.on('data', collect);
      return exitOf(child);
    }, Promise.resolve(0));
  }

  function startBuild(sha: string): void {
    if (device === null) return;
    if (build.state !== 'none' && build.sha === sha && build.state !== 'failed') return;
    buildGeneration += 1;
    stopGroup(buildChild);
    const generation = buildGeneration;
    buildBegan = Date.now();
    const began = buildBegan;
    const incremental = builtOnce;
    const tail: string[] = [];
    const timeout = setTimeout(() => {
      if (generation !== buildGeneration) return;
      tail.push(`the build did not finish in ${BUILD_TIMEOUT_MINUTES} minutes and was stopped`);
      stopGroup(buildChild);
    }, BUILD_TIMEOUT_MINUTES * minuteMs);
    build = { state: 'building', sha, seconds: 0 };
    rmSync(logFile('build'), { force: true });
    const commands: CommandLine[] = [
      { command: 'git', args: ['fetch', '--no-tags', '--depth=1', 'origin', sha] },
      { command: 'git', args: ['checkout', '--force', '--detach', sha] },
      ...device.build(work),
    ];
    // The build it replaces must be gone first: it may still hold git's index lock or be writing the same build directory.
    buildSettled = buildSettled.then(() => runCommands(commands, generation, tail)).then((code) => {
      clearTimeout(timeout);
      if (generation !== buildGeneration) return;
      const seconds = Math.round((Date.now() - began) / 1000);
      if (code === 0) {
        builtOnce = true;
        build = { state: 'built', sha, seconds, incremental };
      } else {
        build = { state: 'failed', sha, seconds, tail: scrub(tail.join('\n')) };
      }
    });
  }

  function health(): SessionHealth {
    const now = Date.now();
    return {
      ok: true,
      v: request.v,
      session: request.session,
      platform: request.platform,
      runner: request.runner,
      device: device === null ? null : { id: deviceId, name: deviceName, ready: existsSync(join(work, 'device-ready')) },
      daemon: proxy !== null && now - daemonOkAt < 3 * tickMs,
      build: build.state === 'building' ? { ...build, seconds: Math.round((now - buildBegan) / 1000) } : build,
      recording: recorder !== null,
      silentSeconds: Math.round((now - lastDriverAt) / 1000),
      idleSeconds: request.idleMinutes * 60,
      capAt: new Date(capAt).toISOString(),
      ending,
    };
  }

  async function stopRecording(): Promise<number> {
    if (recorder === null || device === null) return 0;
    const current = recorder;
    recorder = null;
    const stop = device.record.stop?.(current.file);
    if (stop === undefined) current.child.kill('SIGINT');
    else await runBriefly(stop);
    const code = await Promise.race([current.exited, new Promise<null>((done) => setTimeout(() => done(null), COMMAND_TIMEOUT_MS))]);
    if (code === null) {
      current.child.kill('SIGKILL');
      await current.exited;
    }
    await runBriefly(device.record.collect?.(current.file) ?? []);
    return existsSync(current.file) ? statSync(current.file).size : 0;
  }

  function end(reason: EndReason): void {
    if (ending !== null) return;
    ending = reason;
    void (async () => {
      await stopRecording().catch(() => 0);
      buildGeneration += 1;
      stopGroup(buildChild);
      proxy?.kill('SIGTERM');
      await new Promise((done) => setTimeout(done, 500));
      tunnel.kill('SIGTERM');
      server.close();
      writeFileSync(join(work, 'ended'), `${JSON.stringify({ reason, at: new Date().toISOString(), minutes: Math.round((Date.now() - startedAt) / 6000) / 10 })}\n`);
      process.exit(0);
    })();
  }

  async function handleSim(req: IncomingMessage, res: ServerResponse, url: URL): Promise<void> {
    const route = `${req.method} ${url.pathname.slice('/__sim'.length)}`;
    switch (route) {
      case 'GET /health':
        return json(res, 200, health());
      case 'POST /build': {
        const sha = url.searchParams.get('sha') ?? '';
        if (!/^[0-9a-f]{40}$/.test(sha)) return json(res, 400, { error: 'sha must be a full commit id' });
        if (device === null) return json(res, 409, { error: 'this session has no device to build for' });
        startBuild(sha);
        return json(res, 202, health());
      }
      case 'POST /record/start': {
        if (device === null) return json(res, 409, { error: 'this session has no device to record' });
        // A recorder still running here belongs to a run whose driver died; the new run's recording replaces it.
        await stopRecording();
        const file = join(work, 'recording.mp4');
        rmSync(file, { force: true });
        const start = device.record.start(file);
        const child = spawn(start.command, [...start.args], { cwd: start.cwd, stdio: 'ignore' });
        recorder = { child, exited: exitOf(child), file };
        return json(res, 200, { ok: true });
      }
      case 'POST /record/stop':
        if (recorder === null) return json(res, 409, { error: 'not recording' });
        return json(res, 200, { ok: true, bytes: await stopRecording() });
      case 'GET /record/file': {
        const file = join(work, 'recording.mp4');
        if (!existsSync(file)) return json(res, 404, { error: 'no recording' });
        res.writeHead(200, { 'content-type': 'video/mp4', 'content-length': String(statSync(file).size) });
        createReadStream(file).pipe(res);
        return;
      }
      case 'GET /logs': {
        if (device === null) return json(res, 409, { error: 'this session has no device' });
        const since = new Date(url.searchParams.get('since') ?? Date.now() - 600_000);
        const command = device.logs(Number.isNaN(since.getTime()) ? new Date(Date.now() - 600_000) : since, url.searchParams.get('predicate'));
        const child = spawn(command.command, [...command.args], { cwd: command.cwd, stdio: ['ignore', 'pipe', 'ignore'] });
        res.writeHead(200, { 'content-type': 'text/plain; charset=utf-8' });
        child.stdout.pipe(res);
        child.on('error', () => res.end());
        return;
      }
      case 'GET /runner-log': {
        const name = RUNNER_LOGS.find((known) => known === url.searchParams.get('name'));
        if (name === undefined || !existsSync(logFile(name))) return json(res, 404, { error: `no runner log; names are ${RUNNER_LOGS.join(', ')}` });
        res.writeHead(200, { 'content-type': 'text/plain; charset=utf-8' });
        createReadStream(logFile(name)).pipe(res);
        return;
      }
      case 'POST /stop':
        json(res, 200, { ok: true });
        end('stop');
        return;
      default:
        return json(res, 404, { error: `no route ${route}` });
    }
  }

  function authorized(req: IncomingMessage): boolean {
    const presented = bearer(req);
    if (presented === null || !matchesToken(request.tokenSha256, presented)) return false;
    token ??= presented;
    lastDriverAt = Date.now();
    return true;
  }

  const forwarded = (req: IncomingMessage) => ({ ...req.headers, 'x-forwarded-proto': 'https', 'x-forwarded-host': req.headers.host });

  const server = http.createServer((req, res) => {
    const url = new URL(req.url ?? '/', 'http://localhost');
    if (!authorized(req)) return json(res, 403, { error: 'session token required' });
    if (url.pathname.startsWith('/__sim/')) {
      handleSim(req, res, url).catch((error: Error) => json(res, 500, { error: error.message }));
      return;
    }
    if (!isAgentRoute(url.pathname)) return json(res, 404, { error: `no route ${url.pathname}` });
    if (proxy === null) return json(res, 503, { error: 'agent-device is not up yet' });
    const upstream = http.request({ host: '127.0.0.1', port: agentPort, method: req.method, path: req.url, headers: forwarded(req) }, (up) => {
      res.writeHead(up.statusCode ?? 502, up.headers);
      up.pipe(res);
    });
    upstream.on('error', (error) => {
      if (!res.headersSent) res.writeHead(502, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ error: `agent-device is unreachable: ${error.message}` }));
    });
    req.pipe(upstream);
  });

  server.on('upgrade', (req, socket, head) => {
    if (!authorized(req) || !isAgentRoute(new URL(req.url ?? '/', 'http://localhost').pathname)) {
      socket.end('HTTP/1.1 403 Forbidden\r\n\r\n');
      return;
    }
    const upstream = net.connect(agentPort, '127.0.0.1', () => {
      const headers = Object.entries(forwarded(req))
        .flatMap(([key, value]) => (Array.isArray(value) ? value.map((v) => `${key}: ${v}`) : [`${key}: ${String(value)}`]))
        .join('\r\n');
      upstream.write(`${req.method} ${req.url} HTTP/1.1\r\n${headers}\r\n\r\n`);
      if (head.length > 0) upstream.write(head);
      upstream.pipe(socket);
      socket.pipe(upstream);
    });
    const drop = () => {
      socket.destroy();
      upstream.destroy();
    };
    upstream.on('error', drop);
    socket.on('error', drop);
  });

  setInterval(() => {
    if (ending !== null) return;
    const now = Date.now();
    if (now >= capAt) return end('cap');
    if (now - lastDriverAt >= idleMs) return end('idle');
    ensureProxy();
    void checkDaemon();
  }, tickMs);
  process.on('SIGTERM', () => end('signal'));
  process.on('SIGINT', () => end('signal'));

  server.listen(port, '127.0.0.1', () => {
    console.log(`verify-remote session ${request.session} on :${port}, idle stop ${request.idleMinutes} min, cap ${request.capMinutes} min`);
    if (request.sha !== null) startBuild(request.sha);
  });
}

if (import.meta.main) {
  const [command] = process.argv.slice(2);
  if (command === 'plan') plan();
  else if (command === 'serve') await serve();
  else {
    console.error('usage: session-agent.ts plan | serve');
    process.exit(2);
  }
}
