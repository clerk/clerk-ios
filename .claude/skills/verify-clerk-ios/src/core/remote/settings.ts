import { randomBytes } from 'node:crypto';
import { existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import type { Runner } from '../exec.ts';
import { VerifyFailure, type Platform } from '../types.ts';
import type { GitHub } from './github.ts';
import { LIMITS, REQUEST_VERSION, RUNNER_LABEL, RequestError, parseRequest, sha256Hex, type SessionRequest } from './protocol.ts';

export interface RemoteSettings {
  readonly platform: Platform;
  readonly repo: string;
  readonly workflow: string;
  readonly sessionsDir: string;
  /** The label sessions run on unless `--runner` or VERIFY_REMOTE_RUNNER names another. */
  readonly runner: string;
  /**
   * The label of the short job that reads the request, for a session whose own label comes from the same provider.
   * A session must not wait in one provider's queue for a runner it then takes from another.
   */
  readonly planRunner: string;
  /** A free label with no device, enough for `doctor --live` to prove the plumbing. It also reads the request of a session on any label `planRunner` does not cover, so a free session stays free. */
  readonly plumbingRunner: string;
  readonly device: string;
  readonly idleMinutes: number;
  readonly capMinutes: number;
  /** The agent-device version the driver's e2e engine pins; the session installs the same one. */
  readonly agentDevice: () => string;
  readonly requirement: string;
}

export interface RemoteDeps {
  readonly env: Readonly<Record<string, string | undefined>>;
  readonly runner: Runner;
  /** Replaces the REST client, for tests. */
  readonly github?: () => Promise<GitHub>;
}

function minutes(env: RemoteDeps['env'], name: 'VERIFY_REMOTE_IDLE_MINUTES' | 'VERIFY_REMOTE_CAP_MINUTES', fallback: number, limits: { readonly min: number; readonly max: number }): number {
  const raw = env[name];
  if (raw === undefined || raw === '') return fallback;
  const value = Number(raw);
  if (!Number.isInteger(value) || value < limits.min || value > limits.max) throw new VerifyFailure('USAGE', `${name}=${raw} is not a whole number from ${limits.min} to ${limits.max}`, `unset ${name} or set it within range`);
  return value;
}

const providerOf = (label: string): string => label.split('-')[0]!;

/** The label for the job that reads a request, given the label the session itself will run on. VERIFY_REMOTE_PLAN_RUNNER forces one. */
export function planRunnerFor(settings: RemoteSettings, env: RemoteDeps['env'], sessionRunner: string): string {
  const forced = env.VERIFY_REMOTE_PLAN_RUNNER;
  if (forced !== undefined && forced !== '') {
    if (!RUNNER_LABEL.test(forced)) throw new VerifyFailure('USAGE', `VERIFY_REMOTE_PLAN_RUNNER=${forced} is not a runner label`, 'unset VERIFY_REMOTE_PLAN_RUNNER or set it to a label such as ubuntu-latest');
    return forced;
  }
  return providerOf(sessionRunner) === providerOf(settings.planRunner) ? settings.planRunner : settings.plumbingRunner;
}

/**
 * The id this checkout's sessions carry. It is random, not a hash of the path, because two cloud sandboxes clone to
 * the same path and one must never find, and reap, the other's sessions.
 */
export function driverId(settings: RemoteSettings): string {
  const file = join(settings.sessionsDir, 'owner');
  if (existsSync(file)) {
    const saved = readFileSync(file, 'utf8').trim();
    if (/^[a-f0-9]{12}$/.test(saved)) return saved;
  }
  const id = randomBytes(6).toString('hex');
  mkdirSync(settings.sessionsDir, { recursive: true, mode: 0o700 });
  writeFileSync(file, `${id}\n`, { mode: 0o600 });
  return id;
}

export function newSessionRequest(settings: RemoteSettings, deps: RemoteDeps, input: { readonly mode: SessionRequest['mode']; readonly runner?: string; readonly device: string | null; readonly sha: string | null; readonly idleMinutes?: number; readonly capMinutes?: number }): { readonly request: SessionRequest; readonly token: string } {
  const token = randomBytes(32).toString('hex');
  const capMinutes = input.capMinutes ?? minutes(deps.env, 'VERIFY_REMOTE_CAP_MINUTES', settings.capMinutes, LIMITS.capMinutes);
  const draft: SessionRequest = {
    v: REQUEST_VERSION,
    // A probe run is not a session: its name must not start with the platform, which is how reaping finds sessions.
    session: `${input.mode === 'probe' ? 'probe' : settings.platform}${randomBytes(3).toString('hex')}`,
    owner: driverId(settings),
    mode: input.mode,
    platform: settings.platform,
    runner: input.runner ?? deps.env.VERIFY_REMOTE_RUNNER ?? settings.runner,
    device: input.device,
    sha: input.sha,
    idleMinutes: Math.min(capMinutes, input.idleMinutes ?? minutes(deps.env, 'VERIFY_REMOTE_IDLE_MINUTES', settings.idleMinutes, LIMITS.idleMinutes)),
    capMinutes,
    agentDevice: settings.agentDevice(),
    tokenSha256: sha256Hex(token),
  };
  try {
    return { request: parseRequest(JSON.stringify(draft)), token };
  } catch (error) {
    if (!(error instanceof RequestError)) throw error;
    throw new VerifyFailure('USAGE', `the session request is not valid: ${error.message}`, 'check --runner and VERIFY_REMOTE_RUNNER (a runner label such as ubuntu-latest) and the device name in src/host.ts');
  }
}

export function saveToken(settings: RemoteSettings, session: string, token: string): string {
  const dir = join(settings.sessionsDir, session);
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  const file = join(dir, 'token');
  writeFileSync(file, token, { mode: 0o600 });
  return file;
}

export const forgetSession = (settings: RemoteSettings, session: string): void => rmSync(join(settings.sessionsDir, session), { recursive: true, force: true });
