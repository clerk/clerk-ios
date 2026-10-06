import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { REPLACE_AT_USERS, createClerkBackends, newTestEmail } from '../src/core/clerk.ts';
import { Secret } from '../src/core/secret.ts';
import { VerifyFailure, type PublishableKey, type RunId } from '../src/core/types.ts';

function fakeBapi(routes: Record<string, { status: number; body: unknown }>) {
  const calls: string[] = [];
  const fetchImpl = (async (url: string | URL, init?: RequestInit) => {
    const key = `${init?.method ?? 'GET'} ${String(url).replace('https://api.clerk.com/v1', '').split('?')[0]}`;
    calls.push(key);
    const route = routes[key] ?? { status: 404, body: { errors: [{ code: 'resource_not_found' }] } };
    return new Response(JSON.stringify(route.body), { status: route.status });
  }) as typeof fetch;
  const keys = { pk: 'pk_test_x' as PublishableKey, sk: new Secret('clerk-secret-key', 'sk_test_x') };
  return { calls, backend: createClerkBackends(fetchImpl)(() => keys) };
}

describe('deleteByEmail', () => {
  const email = newTestEmail('r20261003-000000-abcd' as RunId, 1);

  it('deletes the user on an instance without organizations', async () => {
    const { calls, backend } = fakeBapi({
      'GET /users': { status: 200, body: [{ id: 'user_1' }] },
      'GET /users/user_1/organization_memberships': { status: 403, body: { errors: [{ code: 'organization_not_enabled_in_instance' }] } },
      'DELETE /users/user_1': { status: 200, body: { deleted: true } },
    });
    assert.deepEqual(await backend.deleteByEmail(email), { users: 1, organizations: 0 });
    assert.ok(calls.includes('DELETE /users/user_1'));
  });

  it('deletes organizations the user created before the user', async () => {
    const { calls, backend } = fakeBapi({
      'GET /users': { status: 200, body: [{ id: 'user_1' }] },
      'GET /users/user_1/organization_memberships': {
        status: 200,
        body: { data: [{ organization: { id: 'org_own', created_by: 'user_1' } }, { organization: { id: 'org_other', created_by: 'user_2' } }] },
      },
      'DELETE /organizations/org_own': { status: 200, body: {} },
      'DELETE /users/user_1': { status: 200, body: {} },
    });
    assert.deepEqual(await backend.deleteByEmail(email), { users: 1, organizations: 1 });
    assert.equal(calls.includes('DELETE /organizations/org_other'), false);
    assert.ok(calls.indexOf('DELETE /organizations/org_own') < calls.indexOf('DELETE /users/user_1'));
  });

  it('still fails on other BAPI errors', async () => {
    const { backend } = fakeBapi({
      'GET /users': { status: 200, body: [{ id: 'user_1' }] },
      'GET /users/user_1/organization_memberships': { status: 500, body: { errors: [{ code: 'internal' }] } },
    });
    await assert.rejects(backend.deleteByEmail(email), /answered 500/);
  });

  it('previews the same users and organizations without deleting anything', async () => {
    const { calls, backend } = fakeBapi({
      'GET /users': { status: 200, body: [{ id: 'user_1' }] },
      'GET /users/user_1/organization_memberships': {
        status: 200,
        body: { data: [{ organization: { id: 'org_own', name: 'Verify r1', created_by: 'user_1' } }, { organization: { id: 'org_other', name: 'Other', created_by: 'user_2' } }] },
      },
    });
    assert.deepEqual(await backend.previewDeleteByEmail(email), [
      { kind: 'user', id: 'user_1', email },
      { kind: 'organization', id: 'org_own', name: 'Verify r1' },
    ]);
    assert.equal(calls.some((c) => c.startsWith('DELETE')), false);
  });
});

describe('the users of a development instance', () => {
  const email = newTestEmail('r20261003-000000-abcd' as RunId, 1);

  it('counts them with the instance\'s own key', async () => {
    const { calls, backend } = fakeBapi({ 'GET /users/count': { status: 200, body: { object: 'total_count', total_count: 61 } } });
    assert.equal(await backend.userCount(), 61);
    assert.deepEqual(calls, ['GET /users/count']);
  });

  it('turns the refusal of one user too many into a fix a person can follow', async () => {
    const { backend } = fakeBapi({ 'POST /users': { status: 403, body: { errors: [{ code: 'user_quota_exceeded' }] } } });
    await assert.rejects(backend.createUser(email, null), (error: VerifyFailure) => error instanceof VerifyFailure && error.code === 'INSTANCE_MISCONFIGURED' && error.fix === `the next \`{cli} run\` replaces the instance once it holds ${REPLACE_AT_USERS} users; rerun`);
    const other = fakeBapi({ 'POST /users': { status: 403, body: { errors: [{ code: 'something_else' }] } } });
    await assert.rejects(other.backend.createUser(email, null), (error: Error) => !(error instanceof VerifyFailure) && /answered 403/.test(error.message));
  });
});
