import { createHash, timingSafeEqual } from 'node:crypto';
import type { CommandLine } from '../exec.ts';
import type { Platform } from '../types.ts';

export const REQUEST_VERSION = 1 as const;

export type SessionMode = 'probe' | 'session';

/**
 * What a driver asks a provider to start. It travels as one JSON string: a workflow_dispatch input, or the message of
 * the commit pushed to the trigger branch. It holds no secret; `tokenSha256` only lets the session recognize the bearer.
 */
export interface SessionRequest {
  readonly v: typeof REQUEST_VERSION;
  readonly session: string;
  readonly owner: string;
  readonly mode: SessionMode;
  readonly platform: Platform;
  readonly runner: string;
  /** The simulator or emulator to boot. Null starts no device, which is enough to prove the plumbing. */
  readonly device: string | null;
  /** The commit the session checks out and builds. Null builds nothing. */
  readonly sha: string | null;
  readonly idleMinutes: number;
  readonly capMinutes: number;
  readonly agentDevice: string;
  readonly tokenSha256: string;
}

export const LIMITS = { idleMinutes: { min: 1, max: 120 }, capMinutes: { min: 2, max: 360 } } as const;

export const RUNNER_LABEL = /^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$/;

const SHAPE = {
  session: /^[a-z0-9]{4,24}$/,
  owner: /^[a-f0-9]{12}$/,
  runner: RUNNER_LABEL,
  device: /^[A-Za-z0-9][A-Za-z0-9 ._()-]{0,63}$/,
  sha: /^[0-9a-f]{40}$/,
  agentDevice: /^\d+\.\d+\.\d+$/,
  tokenSha256: /^[0-9a-f]{64}$/,
} as const;

export class RequestError extends Error {}

function whole(name: 'idleMinutes' | 'capMinutes', value: unknown): number {
  const { min, max } = LIMITS[name];
  if (typeof value !== 'number' || !Number.isInteger(value) || value < min || value > max) throw new RequestError(`${name} must be a whole number from ${min} to ${max}`);
  return value;
}

export function parseRequest(text: string): SessionRequest {
  let raw: Record<string, unknown>;
  try {
    const parsed: unknown = JSON.parse(text);
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) throw new Error('not an object');
    raw = parsed as Record<string, unknown>;
  } catch {
    throw new RequestError('the request is not a JSON object');
  }
  if (raw.v !== REQUEST_VERSION) throw new RequestError(`request version ${String(raw.v)} is not ${REQUEST_VERSION}`);
  const field = (name: keyof typeof SHAPE, nullable = false): string | null => {
    const value = raw[name];
    if (nullable && value === null) return null;
    if (typeof value !== 'string' || !SHAPE[name].test(value)) throw new RequestError(`${name} is missing or malformed`);
    return value;
  };
  if (raw.mode !== 'probe' && raw.mode !== 'session') throw new RequestError('mode must be probe or session');
  if (raw.platform !== 'ios' && raw.platform !== 'android') throw new RequestError('platform must be ios or android');
  const request: SessionRequest = {
    v: REQUEST_VERSION,
    session: field('session')!,
    owner: field('owner')!,
    mode: raw.mode,
    platform: raw.platform,
    runner: field('runner')!,
    device: field('device', true),
    sha: field('sha', true),
    idleMinutes: whole('idleMinutes', raw.idleMinutes),
    capMinutes: whole('capMinutes', raw.capMinutes),
    agentDevice: field('agentDevice')!,
    tokenSha256: field('tokenSha256')!,
  };
  if (request.idleMinutes > request.capMinutes) throw new RequestError('idleMinutes cannot exceed capMinutes');
  return request;
}

export const sha256Hex = (value: string): string => createHash('sha256').update(value).digest('hex');

export function matchesToken(tokenSha256: string, presented: string): boolean {
  const given = Buffer.from(sha256Hex(presented), 'hex');
  const want = Buffer.from(tokenSha256, 'hex');
  return given.length === want.length && timingSafeEqual(given, want);
}

/** What a probe run echoes, so the driver knows the run it found was started by its own request. */
export const probeEcho = (request: Pick<SessionRequest, 'session' | 'tokenSha256'>): string => sha256Hex(`${request.session}:${request.tokenSha256}`).slice(0, 16);

/**
 * The live return channel is the display name of a job step, which the jobs REST route returns inline while the job
 * runs. Annotations only appear once a job has finished, and artifacts download through a redirect to another host.
 */
export const STEP = {
  probe: (echo: string): string => `verify-remote probe ${echo}`,
  tunnel: (host: string): string => `verify-remote tunnel ${host}`,
  probePattern: /^verify-remote probe ([0-9a-f]{16})$/,
  tunnelPattern: /^verify-remote tunnel ([a-z0-9.-]+)$/,
} as const;

const TRIGGER_BRANCH_PREFIX = 'verify-remote/';
export const triggerBranch = (request: Pick<SessionRequest, 'owner' | 'session'>): string => `${TRIGGER_BRANCH_PREFIX}${request.owner}/${request.session}`;
/** Both triggers title the run so that it ends in `<owner>/<session>`, which is how a driver finds its own sessions. */
export const RUN_TITLE = /(?:^|[ /])([a-f0-9]{12})\/([a-z0-9]{4,24})$/;

export type BuildState =
  | { readonly state: 'none' }
  | { readonly state: 'building'; readonly sha: string; readonly seconds: number }
  | { readonly state: 'built'; readonly sha: string; readonly seconds: number; readonly incremental: boolean }
  | { readonly state: 'failed'; readonly sha: string; readonly seconds: number; readonly tail: string };

export type EndReason = 'stop' | 'idle' | 'cap' | 'tunnel-lost' | 'signal';

export interface SessionHealth {
  readonly ok: true;
  readonly v: typeof REQUEST_VERSION;
  readonly session: string;
  readonly platform: Platform;
  readonly runner: string;
  readonly device: { readonly id: string; readonly name: string; readonly ready: boolean } | null;
  readonly daemon: boolean;
  readonly build: BuildState;
  readonly recording: boolean;
  readonly silentSeconds: number;
  readonly idleSeconds: number;
  readonly capAt: string;
  readonly ending: EndReason | null;
}

/** What a repo tells the session agent about its device and app. The agent owns everything else. */
export interface SessionDevice {
  /** Builds the checked-out tree and puts the app on the device. Runs in order; a non-zero exit fails the build. */
  build(work: string): readonly CommandLine[];
  readonly record: {
    start(file: string): CommandLine;
    /** Runs instead of sending SIGINT to `start`, for recorders that must be stopped on the device. */
    stop?(file: string): readonly CommandLine[];
    /** Runs after `start` has exited, for recorders that write on the device and must be copied to `file`. */
    collect?(file: string): readonly CommandLine[];
  };
  logs(since: Date, predicate: string | null): CommandLine;
}
export type SessionDeviceFactory = (deviceId: string) => SessionDevice;
