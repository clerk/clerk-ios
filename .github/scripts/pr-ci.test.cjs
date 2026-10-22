const assert = require('node:assert/strict');
const { test } = require('node:test');
const { findPullRequests, requestKind, resolveRequest } = require('./pr-ci.cjs');

const SHA = 'a67281b99b151e4aadf15fd568242624e42ee9da';
const OLD_SHA = 'a546d827532ed391fc2dbdf4a9649a11f2719cf6';
const NEXT_SHA = 'b'.repeat(40);
const BOT = { id: 136622811, login: 'coderabbitai[bot]', type: 'Bot' };
const MEMBER = { id: 123, login: 'member', type: 'User' };

function harness() {
  const state = {
    pr: {
      number: 610, state: 'open', draft: false, user: MEMBER, author_association: 'MEMBER',
      head: { sha: SHA, repo: { full_name: 'clerk/clerk-ios' } },
      base: { ref: 'main', repo: { full_name: 'clerk/clerk-ios' } },
    },
    checks: new Map([[SHA, [{ id: 20, head_sha: SHA, app: { slug: 'github-actions' }, status: 'queued' }]]]),
    permission: { permission: 'write', role_name: 'write' },
    outsiders: [],
    writes: [],
    reads: 0,
  };
  const context = { repo: { owner: 'clerk', repo: 'clerk-ios' }, serverUrl: 'https://github.com', runId: 42 };
  const github = {
    rest: {
      pulls: {
        get: async () => {
          state.reads += 1;
          if (state.reads === 2) state.onRecheck?.();
          return { data: structuredClone(state.pr) };
        },
      },
      repos: {
        getCollaboratorPermissionLevel: async () => ({ data: state.permission }),
        listCollaborators: async () => ({ data: state.outsiders }),
      },
      checks: {
        listForRef: async params => ({ data: { check_runs: state.checks.get(params.ref) || [] } }),
        update: async params => {
          state.writes.push({ kind: 'check', ...params });
          const check = [...state.checks.values()].flat().find(check => check.id === params.check_run_id);
          Object.assign(check, params);
          return { data: check };
        },
        create: async params => {
          state.writes.push({ kind: 'check', ...params });
          const check = { ...params, id: 200 + state.writes.length, app: { slug: 'github-actions' } };
          state.checks.set(params.head_sha, [...(state.checks.get(params.head_sha) || []), check]);
          return { data: check };
        },
      },
    },
    paginate: async (method, params) => {
      const { data } = await method(params);
      return data.check_runs || data;
    },
  };
  const evaluate = async () => {
    const outputs = {};
    const messages = [];
    const core = { setOutput: (key, value) => { outputs[key] = value; }, info: text => messages.push(text) };
    await resolveRequest({ github, context, core, prNumber: 610 });
    return { ...outputs, messages };
  };
  const push = (action = 'synchronize', sha = state.pr.head.sha) => {
    state.pr.head.sha = sha;
    context.eventName = 'pull_request_target';
    context.payload = { action, pull_request: structuredClone(state.pr), sender: MEMBER };
  };
  const command = association => {
    context.eventName = 'issue_comment';
    context.payload = {
      action: 'created', issue: { number: 610, pull_request: {} }, sender: MEMBER,
      comment: { user: MEMBER, body: '/run ci', author_association: association },
    };
  };
  const h = { state, context, github, evaluate, push, command };
  push();
  return h;
}

const checkWrites = h => h.state.writes.filter(write => write.kind === 'check');

test('a push by a Clerk member starts the queued Manual CI check at the pushed SHA', async () => {
  const h = harness();
  const result = await h.evaluate();
  assert.equal(result.should_run, 'true');
  assert.equal(result.head_sha, SHA);
  assert.equal(result.manual_check_run_id, 20);
  assert.deepEqual(checkWrites(h).map(write => [write.check_run_id, write.status]), [[20, 'in_progress']]);
});

for (const action of ['opened', 'synchronize', 'reopened', 'ready_for_review']) {
  test(`a ${action} event by a Clerk member runs CI`, async () => {
    const h = harness();
    h.push(action);
    assert.deepEqual(await findPullRequests(h), [610]);
    assert.equal((await h.evaluate()).should_run, 'true');
  });
}

test('every push runs CI on its own head SHA, even after CI ran on an earlier commit', async () => {
  const h = harness();
  assert.equal((await h.evaluate()).should_run, 'true');
  Object.assign(h.state.checks.get(SHA)[0], { status: 'completed', conclusion: 'success' });
  h.push('synchronize', NEXT_SHA);
  const result = await h.evaluate();
  assert.deepEqual([result.should_run, result.head_sha], ['true', NEXT_SHA]);
  assert.deepEqual(h.state.checks.get(NEXT_SHA).map(check => [check.id, check.status]), [[result.manual_check_run_id, 'in_progress']]);
  assert.equal(h.state.checks.get(SHA)[0].status, 'completed');
});

for (const [name, change] of [
  ['external author', h => {
    h.state.pr.author_association = 'CONTRIBUTOR';
    h.state.permission = { permission: 'read', role_name: 'read' };
  }],
  ['outside collaborator author', h => {
    h.state.pr.author_association = 'COLLABORATOR';
    h.state.outsiders = [MEMBER];
  }],
  ['bot author', h => { h.state.pr.user = BOT; }],
  ['draft PR', h => { h.state.pr.draft = true; }],
  ['closed PR', h => { h.state.pr.state = 'closed'; }],
  ['deleted head repository', h => { h.state.pr.head.repo = null; }],
  ['push superseded by a newer commit', h => { h.push('synchronize', OLD_SHA); h.state.pr.head.sha = SHA; }],
  ['head changes during resolution', h => { h.state.onRecheck = () => { h.state.pr.head.sha = NEXT_SHA; }; }],
  ['PR turned draft during resolution', h => { h.state.onRecheck = () => { h.state.pr.draft = true; }; }],
]) {
  test(`${name} never launches automatic CI`, async () => {
    const h = harness();
    change(h);
    assert.equal((await h.evaluate()).should_run, 'false');
    assert.equal(h.state.writes.length, 0);
  });
}

test('a request skips a commit whose Manual CI is already in progress', async () => {
  for (const request of [h => h.push(), h => h.command('MEMBER')]) {
    const h = harness();
    h.state.checks.get(SHA)[0].status = 'in_progress';
    request(h);
    assert.equal((await h.evaluate()).should_run, 'false');
    assert.equal(checkWrites(h).length, 0);
  }
});

test('a private Clerk member, seen as COLLABORATOR by the workflow token, gets automatic CI', async () => {
  const h = harness();
  h.state.pr.author_association = 'COLLABORATOR';
  assert.equal((await h.evaluate()).should_run, 'true');
});

test('fork authored by a Clerk member uses the fork repository and exact pushed SHA', async () => {
  const h = harness();
  h.state.pr.head.repo.full_name = 'member/clerk-ios';
  const result = await h.evaluate();
  assert.equal(result.head_repository, 'member/clerk-ios');
  assert.equal(result.head_sha, SHA);
  assert.equal(result.should_run, 'true');
});

test('a PR stacked on another branch gives that branch as the base to diff against', async () => {
  const h = harness();
  h.state.pr.base.ref = 'mike/parent';
  const result = await h.evaluate();
  assert.deepEqual([result.should_run, result.base_ref], ['true', 'mike/parent']);
});

test('a manual command runs CI on a draft PR', async () => {
  const h = harness();
  h.state.pr.draft = true;
  h.command('MEMBER');
  assert.equal((await h.evaluate()).should_run, 'true');
});

test('failed or cancelled CI can be retried manually on the same commit', async () => {
  for (const conclusion of ['failure', 'cancelled']) {
    const h = harness();
    await h.evaluate();
    Object.assign(h.state.checks.get(SHA)[0], { status: 'completed', conclusion });
    h.command('OWNER');
    const result = await h.evaluate();
    assert.deepEqual([result.should_run, result.head_sha], ['true', SHA]);
    assert.equal(h.state.checks.get(SHA).at(-1).status, 'in_progress');
  }
});

test('manual command retains MEMBER/OWNER authorization and works for an external PR', async () => {
  for (const association of ['MEMBER', 'OWNER', 'COLLABORATOR', 'CONTRIBUTOR', 'NONE']) {
    const h = harness();
    h.state.pr.author_association = 'CONTRIBUTOR';
    h.command(association);
    assert.equal((await h.evaluate()).should_run, ['MEMBER', 'OWNER'].includes(association) ? 'true' : 'false');
  }
});

test('permission lookup failures never launch CI', async () => {
  const h = harness();
  h.state.pr.author_association = 'COLLABORATOR';
  h.github.rest.repos.getCollaboratorPermissionLevel = async () => { throw new Error('403'); };
  await assert.rejects(h.evaluate(), /403/);
  assert.equal(checkWrites(h).length, 0);
});

test('an edited comment never starts CI, even one that checks a Run CI box', async () => {
  const h = harness();
  h.context.eventName = 'issue_comment';
  h.context.payload = {
    action: 'edited', issue: { number: 610, pull_request: {} }, sender: MEMBER,
    comment: { user: MEMBER, author_association: 'MEMBER', body: '- [x] Run CI\n/run ci' },
  };
  assert.equal(requestKind(h.context), null);
  assert.deepEqual(await findPullRequests(h), []);
  assert.equal((await h.evaluate()).should_run, 'false');
  assert.equal(h.state.writes.length, 0);
});

test('non-PR comments and arbitrary events are ignored', () => {
  const h = harness();
  h.command('MEMBER');
  h.context.payload.issue = { number: 610 };
  assert.equal(requestKind(h.context), null);
  h.context.eventName = 'push';
  assert.equal(requestKind(h.context), null);
});

test('bot comments on the conversation are not CI requests', () => {
  const h = harness();
  h.context.eventName = 'issue_comment';
  h.context.payload = {
    action: 'edited', issue: { number: 610, pull_request: {} }, sender: BOT,
    comment: { user: BOT, body: 'No actionable comments were generated in the recent review. 🎉' },
  };
  assert.equal(requestKind(h.context), null);
});

test('review statuses, approvals, workflow runs, and other PR actions never trigger CI', async () => {
  for (const [eventName, payload] of [
    ['status', { sender: BOT, context: 'CodeRabbit', state: 'success', description: 'Review completed', sha: SHA }],
    ['pull_request_review', { action: 'submitted', sender: BOT, pull_request: { number: 610 },
      review: { user: BOT, state: 'approved', commit_id: SHA } }],
    ['workflow_run', { action: 'completed', workflow_run: { path: '.github/workflows/review-activity.yml',
      event: 'pull_request_review_comment', conclusion: 'success', head_sha: SHA, pull_requests: [{ number: 610 }] } }],
    ['pull_request_target', { action: 'labeled', pull_request: { number: 610, head: { sha: SHA } }, sender: MEMBER }],
    ['pull_request_target', { action: 'closed', pull_request: { number: 610, head: { sha: SHA } }, sender: MEMBER }],
  ]) {
    const h = harness();
    Object.assign(h.context, { eventName, payload });
    assert.deepEqual(await findPullRequests(h), []);
    assert.equal((await h.evaluate()).should_run, 'false');
    assert.equal(h.state.writes.length, 0);
  }
});
