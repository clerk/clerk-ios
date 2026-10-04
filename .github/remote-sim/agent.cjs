// Session agent for the remote-sim prototype. Runs on the GitHub runner beside the simulator.
// Every request needs the per-session bearer token. Routes under /agent-device, /health, /rpc, /upload,
// and /artifacts go to the agent-device proxy on the same machine. /__sim/* routes record video,
// read device logs, and end the session, so the driver gets run evidence over the tunnel.
// Shape after native-sim's gate.cjs (MIT, Rodrigo Figueroa), rewritten for this protocol.
const http = require('node:http');
const net = require('node:net');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { spawn, execFile } = require('node:child_process');

const TOKEN = process.env.REMOTE_SIM_TOKEN || '';
const PORT = Number(process.env.REMOTE_SIM_PORT || 3199);
const AGENT_PORT = Number(process.env.REMOTE_SIM_AGENT_PORT || 4310);
const PLATFORM = process.env.REMOTE_SIM_PLATFORM || 'ios';
const DEVICE_ID = process.env.REMOTE_SIM_DEVICE_ID || '';
const WORK = process.env.REMOTE_SIM_WORK || path.join(process.cwd(), 'remote-sim-work');
const STOP_FILE = path.join(WORK, 'stop');
const VIDEO_FILE = path.join(WORK, 'recording.mp4');
const ANDROID_VIDEO = '/sdcard/remote-sim-recording.mp4';
const IOS_LOG_PREDICATE = 'subsystem == "com.clerk.verify" OR subsystem == "com.clerk.sdk"';

if (!TOKEN || !DEVICE_ID) {
  console.error('REMOTE_SIM_TOKEN and REMOTE_SIM_DEVICE_ID are required');
  process.exit(1);
}
fs.mkdirSync(WORK, { recursive: true });

function authorized(req) {
  const match = /^Bearer\s+(.+)$/i.exec((req.headers.authorization || '').trim());
  if (!match) return false;
  const given = Buffer.from(match[1]);
  const want = Buffer.from(TOKEN);
  return given.length === want.length && crypto.timingSafeEqual(given, want);
}

function json(res, status, body) {
  res.writeHead(status, { 'content-type': 'application/json' });
  res.end(JSON.stringify(body));
}

function isAgentRoute(pathname) {
  return ['/agent-device', '/health', '/rpc', '/upload', '/artifacts'].some((p) => pathname === p || pathname.startsWith(`${p}/`));
}

function localTime(date) {
  const pad = (n) => String(n).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}`;
}

function logcatTime(date) {
  const pad = (n) => String(n).padStart(2, '0');
  return `${pad(date.getMonth() + 1)}-${pad(date.getDate())} ${pad(date.getHours())}:${pad(date.getMinutes())}:${pad(date.getSeconds())}.000`;
}

let recorder = null;

function startRecording() {
  if (recorder !== null) return { error: 'already recording' };
  fs.rmSync(VIDEO_FILE, { force: true });
  let child;
  if (PLATFORM === 'ios') {
    child = spawn('xcrun', ['simctl', 'io', DEVICE_ID, 'recordVideo', '--codec=h264', '--force', VIDEO_FILE], { stdio: ['ignore', 'pipe', 'pipe'] });
  } else {
    child = spawn('adb', ['-s', DEVICE_ID, 'shell', 'screenrecord', '--time-limit', '180', ANDROID_VIDEO], { stdio: ['ignore', 'pipe', 'pipe'] });
  }
  const output = [];
  child.stdout.on('data', (d) => output.push(String(d)));
  child.stderr.on('data', (d) => output.push(String(d)));
  const exited = new Promise((resolve) => child.on('close', (code) => resolve(code ?? 1)));
  recorder = { child, exited, output, startedAt: new Date().toISOString() };
  return { ok: true, startedAt: recorder.startedAt };
}

async function stopRecording() {
  if (recorder === null) return { error: 'not recording' };
  const current = recorder;
  recorder = null;
  current.child.kill('SIGINT');
  const code = await Promise.race([current.exited, new Promise((resolve) => setTimeout(() => resolve(null), 30_000))]);
  if (code === null) {
    current.child.kill('SIGKILL');
    await current.exited;
  }
  if (PLATFORM === 'android') {
    await new Promise((resolve) => setTimeout(resolve, 1500));
    await new Promise((resolve) => execFile('adb', ['-s', DEVICE_ID, 'pull', ANDROID_VIDEO, VIDEO_FILE], () => resolve()));
  }
  const bytes = fs.existsSync(VIDEO_FILE) ? fs.statSync(VIDEO_FILE).size : 0;
  return { ok: true, bytes, output: current.output.join('').slice(-2000) };
}

function streamLogs(query, res) {
  const since = new Date(query.get('since') || Date.now() - 600_000);
  let child;
  if (PLATFORM === 'ios') {
    const extra = query.get('predicate');
    const predicate = extra ? `${IOS_LOG_PREDICATE} OR (${extra})` : IOS_LOG_PREDICATE;
    child = spawn('xcrun', ['simctl', 'spawn', DEVICE_ID, 'log', 'show', '--style', 'compact', '--start', localTime(since), '--predicate', predicate]);
  } else {
    child = spawn('adb', ['-s', DEVICE_ID, 'logcat', '-d', '-v', 'threadtime', '-T', logcatTime(since)]);
  }
  res.writeHead(200, { 'content-type': 'text/plain; charset=utf-8' });
  child.stdout.pipe(res);
  child.stderr.on('data', (d) => res.write(String(d)));
  child.on('error', (e) => res.end(`\nlog command failed: ${e.message}\n`));
}

async function handleSim(req, res, url) {
  const route = url.pathname.slice('/__sim'.length);
  if (route === '/health' && req.method === 'GET') {
    return json(res, 200, { ok: true, platform: PLATFORM, deviceId: DEVICE_ID, recording: recorder !== null, stopped: fs.existsSync(STOP_FILE) });
  }
  if (route === '/record/start' && req.method === 'POST') {
    const result = startRecording();
    return json(res, result.error ? 409 : 200, result);
  }
  if (route === '/record/stop' && req.method === 'POST') {
    const result = await stopRecording();
    return json(res, result.error ? 409 : 200, result);
  }
  if (route === '/record/file' && req.method === 'GET') {
    if (!fs.existsSync(VIDEO_FILE)) return json(res, 404, { error: 'no recording' });
    res.writeHead(200, { 'content-type': 'video/mp4', 'content-length': String(fs.statSync(VIDEO_FILE).size) });
    return fs.createReadStream(VIDEO_FILE).pipe(res);
  }
  if (route === '/logs' && req.method === 'GET') return streamLogs(url.searchParams, res);
  if (route === '/stop' && req.method === 'POST') {
    fs.writeFileSync(STOP_FILE, new Date().toISOString());
    return json(res, 200, { ok: true });
  }
  return json(res, 404, { error: `no route ${req.method} ${url.pathname}` });
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (!authorized(req)) return json(res, 403, { error: 'session token required' });
  if (url.pathname.startsWith('/__sim/')) {
    handleSim(req, res, url).catch((e) => json(res, 500, { error: e.message }));
    return;
  }
  if (!isAgentRoute(url.pathname)) return json(res, 404, { error: `no route ${url.pathname}` });
  const upstream = http.request(
    { host: '127.0.0.1', port: AGENT_PORT, method: req.method, path: req.url, headers: { ...req.headers, 'x-forwarded-proto': 'https', 'x-forwarded-host': req.headers.host } },
    (up) => {
      res.writeHead(up.statusCode || 502, up.headers);
      up.pipe(res);
    },
  );
  upstream.on('error', (err) => {
    if (!res.headersSent) res.writeHead(502, { 'content-type': 'text/plain' });
    res.end(`upstream error: ${err.message}`);
  });
  req.pipe(upstream);
});

server.on('upgrade', (req, socket, head) => {
  if (!authorized(req) || !isAgentRoute(new URL(req.url, 'http://localhost').pathname)) {
    socket.end('HTTP/1.1 403 Forbidden\r\n\r\n');
    return;
  }
  const upstream = net.connect(AGENT_PORT, '127.0.0.1', () => {
    const headers = Object.entries({ ...req.headers, 'x-forwarded-proto': 'https', 'x-forwarded-host': req.headers.host })
      .map(([k, v]) => (Array.isArray(v) ? v.map((x) => `${k}: ${x}`).join('\r\n') : `${k}: ${v}`))
      .join('\r\n');
    upstream.write(`${req.method} ${req.url} HTTP/1.1\r\n${headers}\r\n\r\n`);
    if (head && head.length) upstream.write(head);
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

server.listen(PORT, '127.0.0.1', () => {
  console.log(`remote-sim agent on :${PORT} (agent-device -> :${AGENT_PORT}, ${PLATFORM} ${DEVICE_ID})`);
});
