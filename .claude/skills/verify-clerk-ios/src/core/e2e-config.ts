import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import type { E2EConfig } from 'e2e';
import { mobile, type DeviceProvider } from '@e2e-dev/mobile';
import { Secret } from './secret.ts';
import { VerifyFailure, type Lease, type RemoteLease, type RunContext } from './types.ts';
import { agentDeviceStateDir } from './workspace.ts';

export const ASSERTION_TIMEOUT_MS = 10_000;

const SKILL_DIR = join(dirname(fileURLToPath(import.meta.url)), '..', '..');

export const STANDING_CONTEXT = join(SKILL_DIR, '.verify', 'context.json');

function parseContext(text: string, source: string): RunContext {
  const raw = JSON.parse(text) as Partial<RunContext>;
  if (raw.v !== 1 || typeof raw.workspace !== 'string' || !Array.isArray(raw.targets) || typeof raw.agentDeviceSession !== 'string') {
    throw new VerifyFailure('NOT_READY', `${source} is not a verify run context`, 'run specs through `verify run`');
  }
  return raw as RunContext;
}

export function loadRunContext(env: Readonly<Record<string, string | undefined>> = process.env): RunContext {
  const named = env.VERIFY_CONTEXT;
  if (named !== undefined && named !== '') return parseContext(readFileSync(named, 'utf8'), named);
  if (!existsSync(STANDING_CONTEXT)) {
    throw new VerifyFailure('NOT_READY', 'no device is leased for this worktree', '{cli} up');
  }
  const context = parseContext(readFileSync(STANDING_CONTEXT, 'utf8'), STANDING_CONTEXT);
  if (!context.targets.every((t) => existsSync(t.leaseFile))) throw new VerifyFailure('NOT_READY', 'the lease this context names was released', '{cli} up');
  return context;
}

function remoteDevice(lease: RemoteLease): DeviceProvider {
  const token = new Secret('session-bearer', readFileSync(lease.tokenFile, 'utf8').trim());
  return {
    name: `remote-${lease.provider}`,
    acquire: async () => ({
      id: lease.session,
      deviceId: lease.deviceId,
      device: lease.deviceName,
      daemon: token.use('e2e-provider-lease', (authToken) => ({ baseUrl: `${lease.baseUrl}/agent-device`, authToken })),
    }),
    release: async () => {},
  };
}

export function composeE2EConfig(context: RunContext): E2EConfig {
  process.env.AGENT_DEVICE_STATE_DIR ??= agentDeviceStateDir(context.workspace);
  const targets = context.targets.map((target) => {
    const lease = JSON.parse(readFileSync(target.leaseFile, 'utf8')) as Lease;
    if (lease.backend === 'remote') {
      return {
        name: target.platform,
        engine: mobile({ platform: target.platform, device: remoteDevice(lease), session: context.agentDeviceSession, videoTouches: false }),
        app: { bundleId: target.appId },
      };
    }
    return {
      name: target.platform,
      engine: mobile({ platform: target.platform, device: [lease.deviceId], session: context.agentDeviceSession, videoTouches: false }),
      app: { bundleId: target.appId, appPath: target.appPath },
    };
  });
  return {
    tests: ['specs/**/*.e2e.ts'],
    targets,
    workers: 1,
    retries: 0,
    assertionTimeout: ASSERTION_TIMEOUT_MS,
    trace: 'off',
  };
}

export async function withJudge(config: E2EConfig, env: Readonly<Record<string, string | undefined>> = process.env): Promise<E2EConfig> {
  const spec = env.VERIFY_JUDGE_MODEL;
  if (spec === undefined || spec === '') return config;
  const match = /^chatgpt:(.+)$/.exec(spec);
  if (match === null) throw new VerifyFailure('USAGE', `VERIFY_JUDGE_MODEL=${spec} is not chatgpt:<model-id>`, 'export VERIFY_JUDGE_MODEL=chatgpt:<model-id>, or unset it');
  try {
    const { chatgpt } = await import('e2e/oauth/chatgpt');
    return { ...config, agents: { default: { model: chatgpt(match[1]!) } } };
  } catch (error) {
    throw new VerifyFailure(
      'NOT_READY',
      `the AI judge could not load: ${(error as Error).message}`,
      `cd ${SKILL_DIR} && npm i -D ai @ai-sdk/openai && npx e2e login openai`,
    );
  }
}
