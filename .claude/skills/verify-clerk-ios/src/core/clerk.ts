import { Secret } from './secret.ts';
import type { InstanceKeys } from './keys.ts';
import {
  VerifyFailure,
  type InstanceName,
  type PublishableKey,
  type RunId,
  type SeededUser,
  type TestEmail,
  type TestPhone,
} from './types.ts';

export interface InstanceRequirements {
  readonly strategies: readonly string[];
  readonly organizations: boolean;
}

export const INSTANCE_REQUIREMENTS: Readonly<Record<InstanceName, InstanceRequirements>> = {
  'with-email-codes': { strategies: ['email_code', 'ticket'], organizations: true },
  'with-session-tasks': { strategies: ['email_code', 'ticket'], organizations: true },
  'with-session-tasks-setup-mfa': { strategies: ['email_code', 'ticket'], organizations: false },
};

export function frontendApiHost(pk: PublishableKey): string {
  const decoded = Buffer.from(pk.replace(/^pk_(test|live)_/, ''), 'base64url').toString('utf8');
  return decoded.replace(/\$$/, '');
}

function notTestIdentity(value: string, kind: string): VerifyFailure {
  return new VerifyFailure('NOT_TEST_IDENTITY', `${value} is not a ${kind}`, 'use an address with +clerk_test or a 555-0100..0199 phone that this run created');
}

export function newTestEmail(run: RunId, n: number): TestEmail {
  const runPart = run.toLowerCase().replace(/[^a-z0-9]/g, '_');
  return parseTestEmail(`verify_${runPart}_${n}+clerk_test@example.com`);
}

const TEST_EMAIL = /^[a-z0-9._-]+\+clerk_test@[a-z0-9.-]+\.[a-z]+$/;
export function parseTestEmail(value: string): TestEmail {
  if (!TEST_EMAIL.test(value)) throw notTestIdentity(value, '+clerk_test email');
  return value as TestEmail;
}

export function parseTestPhone(value: string): TestPhone {
  const digits = value.replace(/[^0-9]/g, '');
  const national = digits.length === 11 && digits.startsWith('1') ? digits.slice(1) : digits;
  if (!/^[2-9]\d{2}55501\d{2}$/.test(national)) throw notTestIdentity(value, '555-0100..0199 test phone');
  return `+1${national}` as TestPhone;
}

/** What `deleteByEmail` would delete: a user, or an organization that user created. */
export type OwnedTarget = { readonly kind: 'user'; readonly id: string; readonly email: TestEmail } | { readonly kind: 'organization'; readonly id: string; readonly name: string };

/** The Backend API of the one instance whose keys the backend was made with. */
export interface ClerkBackend {
  createUser(email: TestEmail, phone: TestPhone | null): Promise<SeededUser>;
  mintTicket(user: SeededUser, expiresInSeconds: number): Promise<Secret<'ticket'>>;
  deleteByEmail(email: TestEmail): Promise<{ readonly users: number; readonly organizations: number }>;
  previewDeleteByEmail(email: TestEmail): Promise<readonly OwnedTarget[]>;
  findUserId(email: TestEmail): Promise<string | null>;
  /** A development instance refuses its 101st user. */
  userCount(): Promise<number>;
  settings(): Promise<InstanceRequirements>;
  /** Makes one read with the instance's own key and returns the Backend API host that accepted it. */
  apiHost(): Promise<BackendApiHost>;
}

export type StandingClerk = (instance: InstanceName) => ClerkBackend;

export const DEVELOPMENT_USER_LIMIT = 100;
/** An instance that holds this many users is replaced before a run starts on it. A full run of a repository's specs seeds about twelve. */
export const REPLACE_AT_USERS = 60;

/**
 * `api.clerk.dev` is the older name of the same API. A cloud environment can hold a credential for `api.clerk.com`
 * that replaces the Authorization header of every request to that host, and then an instance's own key only arrives
 * on the older name. Nothing promises that name stays, so it is used only after `api.clerk.com` refused the key.
 */
export const BACKEND_API_HOSTS = ['api.clerk.com', 'api.clerk.dev'] as const;
export type BackendApiHost = (typeof BACKEND_API_HOSTS)[number];

export const BACKEND_API_FIX =
  'in a cloud environment, set Path prefixes on the API credential for api.clerk.com to /v1/platform/ so it is attached to Platform API calls only, and add api.clerk.dev to the allowed domains';

class ClerkHttpError extends Error {
  readonly status: number;
  readonly codes: readonly string[];
  constructor(status: number, codes: readonly string[], path: string) {
    super(`Clerk ${path} answered ${status}${codes.length ? ` (${codes.join(', ')})` : ''}`);
    this.status = status;
    this.codes = codes;
  }
}

/**
 * Returns a maker of backends that share one choice of Backend API host for the process. Each backend reads `keys`
 * when a call is made, so one backend can serve whichever instance a run is on at that moment.
 */
export function createClerkBackends(fetchImpl: typeof fetch = fetch, onFallback: (line: string) => void = () => undefined): (keys: () => InstanceKeys) => ClerkBackend {
  let host: BackendApiHost = BACKEND_API_HOSTS[0];

  async function request(keys: InstanceKeys, method: string, path: string, body?: unknown): Promise<unknown> {
    const { sk } = keys;
    const send = async (to: BackendApiHost): Promise<{ readonly status: number; readonly text: string }> => {
      const response = await sk.use('bapi-authorization', (plain) =>
        fetchImpl(`https://${to}/v1${path}`, {
          method,
          headers: { Authorization: `Bearer ${plain}`, 'Content-Type': 'application/json' },
          ...(body === undefined ? {} : { body: JSON.stringify(body) }),
        }),
      );
      return { status: response.status, text: await response.text() };
    };
    let answer = await send(host);
    if (answer.status === 401 && host === BACKEND_API_HOSTS[0]) {
      // A request that got 401 changed nothing, so sending it again to the other name is safe.
      const other = await send(BACKEND_API_HOSTS[1]).catch(() => null);
      if (other !== null && other.status >= 200 && other.status < 300) {
        host = BACKEND_API_HOSTS[1];
        onFallback(`clerk   ${BACKEND_API_HOSTS[0]} answered 401 to the instance's own secret key and ${host} accepted it, so something replaces the Authorization header on ${BACKEND_API_HOSTS[0]}; using ${host} for the Backend API`);
        answer = other;
      }
    }
    let json: unknown = null;
    try {
      json = answer.text.length > 0 ? JSON.parse(answer.text) : null;
    } catch {
      json = null;
    }
    if (answer.status < 200 || answer.status >= 300) {
      const errors = (json as { errors?: { code?: string }[] } | null)?.errors ?? [];
      throw new ClerkHttpError(answer.status, errors.map((e) => e.code ?? 'unknown'), `${method} ${path.split('?')[0]}`);
    }
    return json;
  }

  return (keys) => {
    const bapi = (method: string, path: string, body?: unknown): Promise<unknown> => request(keys(), method, path, body);

    async function ownedOrganizations(userId: string): Promise<readonly { readonly id: string; readonly name: string }[]> {
      const memberships = (await bapi('GET', `/users/${userId}/organization_memberships?limit=100`).catch((error: unknown) => {
        if (error instanceof ClerkHttpError && error.codes.includes('organization_not_enabled_in_instance')) return { data: [] };
        throw error;
      })) as { data?: { organization?: { id?: string; name?: string; created_by?: string } }[] };
      return (memberships.data ?? []).flatMap(({ organization: org }) =>
        typeof org?.id === 'string' && org.created_by === userId ? [{ id: org.id, name: org.name ?? '' }] : [],
      );
    }

    async function usersByEmail(email: TestEmail): Promise<readonly { id: string }[]> {
      const users = await bapi('GET', `/users?email_address=${encodeURIComponent(email)}`);
      return Array.isArray(users) ? users.filter((u): u is { id: string } => typeof u?.id === 'string') : [];
    }

    return {
      async createUser(email, phone) {
        const created = (await bapi('POST', '/users', {
          email_address: [email],
          ...(phone === null ? {} : { phone_number: [phone] }),
          skip_password_requirement: true,
        }).catch((error: unknown) => {
          if (!(error instanceof ClerkHttpError && error.status === 403 && error.codes.includes('user_quota_exceeded'))) throw error;
          throw new VerifyFailure('INSTANCE_MISCONFIGURED', `the instance holds the ${DEVELOPMENT_USER_LIMIT} users a development instance allows, and Clerk refused one more`, `the next \`{cli} run\` replaces the instance once it holds ${REPLACE_AT_USERS} users; rerun`);
        })) as { id?: unknown };
        if (typeof created.id !== 'string') throw new Error('Clerk created a user without an id');
        return { id: created.id, email, phone };
      },
      async mintTicket(user, expiresInSeconds) {
        const token = (await bapi('POST', '/sign_in_tokens', { user_id: user.id, expires_in_seconds: expiresInSeconds })) as { token?: unknown };
        if (typeof token.token !== 'string') throw new Error('Clerk returned a sign-in token without a token');
        return new Secret('ticket', token.token);
      },
      async findUserId(email) {
        return (await usersByEmail(email))[0]?.id ?? null;
      },
      async previewDeleteByEmail(email) {
        const targets: OwnedTarget[] = [];
        for (const user of await usersByEmail(email)) {
          targets.push({ kind: 'user', id: user.id, email });
          for (const org of await ownedOrganizations(user.id)) targets.push({ kind: 'organization', ...org });
        }
        return targets;
      },
      async userCount() {
        const counted = (await bapi('GET', '/users/count')) as { total_count?: unknown } | null;
        if (typeof counted?.total_count !== 'number') throw new Error('Clerk counted the users of the instance without a total');
        return counted.total_count;
      },
      async deleteByEmail(email) {
        let users = 0;
        let organizations = 0;
        for (const user of await usersByEmail(email)) {
          for (const org of await ownedOrganizations(user.id)) {
            try {
              await bapi('DELETE', `/organizations/${org.id}`);
              organizations += 1;
            } catch (error) {
              if (!(error instanceof ClerkHttpError && error.status === 404)) throw error;
            }
          }
          try {
            await bapi('DELETE', `/users/${user.id}`);
            users += 1;
          } catch (error) {
            if (!(error instanceof ClerkHttpError && error.status === 404)) throw error;
          }
        }
        return { users, organizations };
      },
      async apiHost() {
        await bapi('GET', '/users?limit=1');
        return host;
      },
      async settings() {
        const host = frontendApiHost(keys().pk);
        const response = await fetchImpl(`https://${host}/v1/environment`);
        if (!response.ok) throw new Error(`FAPI environment answered ${response.status}`);
        const env = (await response.json()) as {
          user_settings?: { attributes?: Record<string, { enabled?: boolean; first_factors?: string[]; second_factors?: string[]; verifications?: string[] }> };
          organization_settings?: { enabled?: boolean };
        };
        const found = new Set<string>();
        for (const [name, attribute] of Object.entries(env.user_settings?.attributes ?? {})) {
          if (!attribute.enabled) continue;
          if (name === 'ticket') found.add('ticket');
          for (const s of [...(attribute.first_factors ?? []), ...(attribute.second_factors ?? []), ...(attribute.verifications ?? [])]) found.add(s);
        }
        return { strategies: [...found].sort(), organizations: env.organization_settings?.enabled === true };
      },
    };
  };
}

export const isUnauthorized = (error: unknown): boolean => error instanceof ClerkHttpError && error.status === 401;

export function isConflict(error: unknown): boolean {
  return error instanceof ClerkHttpError && error.status === 422;
}
