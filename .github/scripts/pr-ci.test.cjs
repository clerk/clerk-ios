const assert = require('node:assert/strict');
const { test } = require('node:test');
const { findPullRequests, requestKind, resolveRequest } = require('./pr-ci.cjs');

const SHA = 'a67281b99b151e4aadf15fd568242624e42ee9da';
const OLD_SHA = 'a546d827532ed391fc2dbdf4a9649a11f2719cf6';
const NEXT_SHA = 'b'.repeat(40);
const RABBIT = { id: 136622811, login: 'coderabbitai[bot]', type: 'Bot' };
const ACTIONS = { id: 41898282, login: 'github-actions[bot]', type: 'Bot' };
const MEMBER = { id: 123, login: 'member', type: 'User' };
const INSTRUCTIONS = '<!-- clerk-ios-manual-ci -->\n- [ ] Run CI';
const RELAY_PATH = '.github/workflows/coderabbit-review-activity.yml';
const RABBIT_AUTHOR = { __typename: 'Bot', login: 'coderabbitai' };
const thread = (isResolved, author = RABBIT_AUTHOR) => ({ isResolved, comments: { nodes: [{ author }] } });

function harness() {
  const state = {
    pr: {
      number: 610, state: 'open', draft: false, user: MEMBER, author_association: 'MEMBER',
      head: { sha: SHA, repo: { full_name: 'clerk/clerk-ios' } },
      base: { repo: { full_name: 'clerk/clerk-ios' } },
    },
    comments: [{ id: 1, user: ACTIONS, body: INSTRUCTIONS }],
    // Pages of review threads, as returned by GraphQL.
    threadPages: [[thread(true)]],
    statuses: [{ id: 10, context: 'CodeRabbit', creator: RABBIT, state: 'success', description: 'Review completed' }],
    checks: new Map([[SHA, [{ id: 20, head_sha: SHA, app: { slug: 'github-actions' }, status: 'queued' }]]]),
    commits: [{ sha: SHA }],
    permission: { permission: 'write', role_name: 'write' },
    outsiders: [],
    writes: [],
    reads: 0,
  };
  const context = {
    repo: { owner: 'clerk', repo: 'clerk-ios' }, serverUrl: 'https://github.com', runId: 42,
    eventName: 'status',
    payload: { sender: RABBIT, context: 'CodeRabbit', state: 'success', description: 'Review completed', sha: SHA },
  };
  const github = {
    rest: {
      pulls: {
        get: async () => {
          state.reads += 1;
          if (state.reads === 2) state.onRecheck?.();
          return { data: structuredClone(state.pr) };
        },
        listCommits: async () => ({ data: state.commits }),
      },
      repos: {
        getCollaboratorPermissionLevel: async () => ({ data: state.permission }),
        listCollaborators: async () => ({ data: state.outsiders }),
        listCommitStatusesForRef: async () => ({ data: state.statuses }),
        listPullRequestsAssociatedWithCommit: async () => ({ data: state.associated || [state.pr] }),
      },
      issues: {
        listComments: async () => ({ data: state.comments }),
        createComment: async params => {
          state.writes.push({ kind: 'comment', ...params });
          const comment = { ...params, id: 100 + state.comments.length, user: ACTIONS };
          state.comments.push(comment);
          return { data: comment };
        },
        updateComment: async params => {
          state.writes.push({ kind: 'edit', ...params });
          const comment = state.comments.find(comment => comment.id === params.comment_id);
          comment.body = params.body;
          return { data: comment };
        },
      },
      checks: {
        listForRef: async params => ({ data: { check_runs: state.checks.get(params.ref) || [] } }),
        update: async params => {
          if (state.checkWriteError) throw new Error('Check write failed');
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
    graphql: async (query, { cursor }) => {
      const page = cursor ? Number(cursor) : 0;
      const hasNextPage = page + 1 < state.threadPages.length;
      return { repository: { pullRequest: { reviewThreads: {
        nodes: state.threadPages[page], pageInfo: { hasNextPage, endCursor: hasNextPage ? String(page + 1) : null },
      } } } };
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
  const command = association => {
    context.eventName = 'issue_comment';
    context.payload = {
      action: 'created', issue: { number: 610, pull_request: {} }, sender: MEMBER,
      comment: { user: MEMBER, body: '/run ci', author_association: association },
    };
  };
  const statusEvent = () => {
    context.eventName = 'status';
    context.payload = { sender: RABBIT, context: 'CodeRabbit', state: 'success', description: 'Review completed', sha: state.pr.head.sha };
  };
  const relayEvent = () => {
    context.eventName = 'workflow_run';
    context.payload = { action: 'completed', workflow_run: {
      path: RELAY_PATH, event: 'pull_request_review_comment', conclusion: 'success', head_sha: state.pr.head.sha,
    } };
  };
  const checkbox = () => {
    context.eventName = 'issue_comment';
    context.payload = {
      action: 'edited', issue: { number: 610, pull_request: {} }, sender: MEMBER,
      comment: { ...state.comments[0], body: INSTRUCTIONS.replace('[ ]', '[x]') },
    };
  };
  return { state, context, github, evaluate, command, statusEvent, relayEvent, checkbox };
}

test('a completed review with resolved threads starts the existing queued check at the reviewed SHA', async () => {
  const h = harness();
  const result = await h.evaluate();
  assert.equal(result.should_run, 'true');
  assert.equal(result.head_sha, SHA);
  assert.equal(result.manual_check_run_id, 20);
  assert.deepEqual(h.state.writes.map(write => write.kind), ['comment', 'check']);
  assert.match(h.state.writes[0].body, /clerk-ios-pr-ci-started/);
});

test('a PR with no review threads starts CI once CodeRabbit completes its review', async () => {
  const h = harness();
  h.state.threadPages = [[]];
  assert.equal((await h.evaluate()).should_run, 'true');
});

test('an unresolved CodeRabbit thread waits until a later commit is reviewed with it resolved', async () => {
  const h = harness();
  h.state.threadPages = [[thread(false)]];
  assert.equal((await h.evaluate()).should_run, 'false');
  assert.equal(h.state.writes.length, 0);
  h.state.threadPages = [[thread(true)]];
  assert.equal((await h.evaluate()).should_run, 'true');
});

test('a thread resolved after the green status starts CI from the relayed review activity', async () => {
  const h = harness();
  h.state.threadPages = [[thread(false)]];
  assert.equal((await h.evaluate()).should_run, 'false');
  h.state.threadPages = [[thread(true)]];
  h.relayEvent();
  assert.deepEqual(await findPullRequests(h), [610]);
  assert.equal((await h.evaluate()).should_run, 'true');
  assert.equal(h.state.writes.filter(write => write.kind === 'check').length, 1);
});

test('unresolved CodeRabbit threads on later pages also block automatic CI', async () => {
  const h = harness();
  h.state.threadPages = [[thread(true)], [thread(true), thread(false)]];
  assert.equal((await h.evaluate()).should_run, 'false');
});

test('unresolved threads from people, or impersonating CodeRabbit, do not block automatic CI', async () => {
  const h = harness();
  h.state.threadPages = [[
    thread(true), thread(false, { __typename: 'User', login: 'member' }),
    thread(false, { __typename: 'User', login: 'coderabbitai' }),
  ]];
  assert.equal((await h.evaluate()).should_run, 'true');
});

test('a relayed event is only a hint and still requires the completed review', async () => {
  const h = harness();
  h.state.statuses[0].state = 'pending';
  h.relayEvent();
  assert.equal((await h.evaluate()).should_run, 'false');
  assert.equal(h.state.writes.length, 0);
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
  ['bot author', h => { h.state.pr.user = RABBIT; }],
  ['draft PR', h => { h.state.pr.draft = true; }],
  ['closed PR', h => { h.state.pr.state = 'closed'; }],
  ['deleted head repository', h => { h.state.pr.head.repo = null; }],
  ['unresolved CodeRabbit thread', h => { h.state.threadPages = [[thread(true), thread(false)]]; }],
  ['stale status event', h => { h.statusEvent(); h.context.payload.sha = OLD_SHA; }],
  ['skipped review with green status', h => { h.state.statuses[0].description = 'Review skipped'; }],
  ['failed review', h => { h.state.statuses[0].state = 'failure'; }],
  ['newer pending review of the same SHA', h => { h.state.statuses.push({ ...h.state.statuses[0], id: 11, state: 'pending' }); }],
  ['spoofed CodeRabbit status', h => { h.state.statuses[0].creator = MEMBER; }],
  ['CodeRabbit status from another account', h => { h.context.payload.sender = MEMBER; }],
  ['relay from another workflow', h => { h.relayEvent(); h.context.payload.workflow_run.path = '.github/workflows/other.yml'; }],
  ['failed relay run', h => { h.relayEvent(); h.context.payload.workflow_run.conclusion = 'failure'; }],
  ['head changes during resolution', h => { h.state.onRecheck = () => { h.state.pr.head.sha = NEXT_SHA; }; }],
]) {
  test(`${name} never launches automatic CI`, async () => {
    const h = harness();
    change(h);
    assert.equal((await h.evaluate()).should_run, 'false');
    assert.equal(h.state.writes.length, 0);
  });
}

test('a private Clerk member, seen as COLLABORATOR by the workflow token, gets automatic CI', async () => {
  const h = harness();
  h.state.pr.author_association = 'COLLABORATOR';
  assert.equal((await h.evaluate()).should_run, 'true');
});

test('fork authored by a Clerk member uses the fork repository and exact reviewed SHA', async () => {
  const h = harness();
  h.state.pr.head.repo.full_name = 'member/clerk-ios';
  const result = await h.evaluate();
  assert.equal(result.head_repository, 'member/clerk-ios');
  assert.equal(result.head_sha, SHA);
  assert.equal(result.should_run, 'true');
});

test('marking a reviewed draft ready evaluates the existing clean review', async () => {
  const h = harness();
  h.context.eventName = 'pull_request_target';
  h.context.payload = { action: 'ready_for_review', pull_request: h.state.pr, sender: MEMBER };
  assert.deepEqual(await findPullRequests(h), [610]);
  assert.equal((await h.evaluate()).should_run, 'true');
});

test('a later clean commit stays manual after the first kickoff, even after force-push', async () => {
  const h = harness();
  assert.equal((await h.evaluate()).should_run, 'true');
  h.state.pr.head.sha = NEXT_SHA;
  h.state.commits = [{ sha: NEXT_SHA }];
  h.state.checks.clear();
  h.statusEvent();
  assert.equal((await h.evaluate()).should_run, 'false');
  h.command('MEMBER');
  assert.equal((await h.evaluate()).should_run, 'true');
});

test('a manual kickoff before CodeRabbit finishes consumes the first kickoff', async () => {
  const h = harness();
  h.command('MEMBER');
  assert.equal((await h.evaluate()).should_run, 'true');
  h.state.checks.get(SHA)[0].status = 'completed';
  h.statusEvent();
  assert.equal((await h.evaluate()).should_run, 'false');
});

test('failed or cancelled CI can be retried manually without another automatic run', async () => {
  for (const conclusion of ['failure', 'cancelled']) {
    const h = harness();
    await h.evaluate();
    Object.assign(h.state.checks.get(SHA)[0], { status: 'completed', conclusion });
    assert.equal((await h.evaluate()).should_run, 'false');
    h.command('OWNER');
    assert.equal((await h.evaluate()).should_run, 'true');
    assert.equal(h.state.writes.filter(write => write.kind === 'comment').length, 1);
  }
});

test('historical CI on an earlier commit consumes the first kickoff, queued placeholders do not', async () => {
  for (const status of ['queued', 'in_progress', 'completed']) {
    const h = harness();
    h.state.commits.unshift({ sha: OLD_SHA });
    h.state.checks.set(OLD_SHA, [{ id: 19, head_sha: OLD_SHA, app: { slug: 'github-actions' }, status }]);
    assert.equal((await h.evaluate()).should_run, status === 'queued' ? 'true' : 'false');
    assert.equal(h.state.writes.filter(write => write.kind === 'check').length, status === 'queued' ? 1 : 0);
  }
});

test('untrusted copies of the kickoff marker cannot suppress the first run', async () => {
  const h = harness();
  h.state.comments.push({ id: 3, user: MEMBER, body: '<!-- clerk-ios-pr-ci-started -->' });
  assert.equal((await h.evaluate()).should_run, 'true');
});

test('failure after claiming the first kickoff cannot cause an automatic retry', async () => {
  const h = harness();
  h.state.checkWriteError = true;
  await assert.rejects(h.evaluate(), /Check write failed/);
  h.state.checkWriteError = false;
  assert.equal((await h.evaluate()).should_run, 'false');
  h.command('MEMBER');
  assert.equal((await h.evaluate()).should_run, 'true');
});

test('manual command retains MEMBER/OWNER authorization and works for an external PR', async () => {
  for (const association of ['MEMBER', 'OWNER', 'COLLABORATOR', 'CONTRIBUTOR', 'NONE']) {
    const h = harness();
    h.state.pr.author_association = 'CONTRIBUTOR';
    h.command(association);
    assert.equal((await h.evaluate()).should_run, ['MEMBER', 'OWNER'].includes(association) ? 'true' : 'false');
  }
});

test('checkbox requires an internal writer and resets after use', async () => {
  const h = harness();
  h.checkbox();
  assert.equal((await h.evaluate()).should_run, 'true');
  assert.equal(h.state.comments[0].body, INSTRUCTIONS);
  for (const kind of ['outside', 'reader']) {
    const denied = harness();
    denied.checkbox();
    if (kind === 'outside') denied.state.outsiders = [MEMBER];
    else denied.state.permission = { permission: 'read', role_name: 'read' };
    assert.equal((await denied.evaluate()).should_run, 'false');
    assert.equal(denied.state.writes.filter(write => write.kind === 'check').length, 0);
  }
});

test('permission lookup failures never launch CI', async () => {
  const h = harness();
  h.checkbox();
  h.github.rest.repos.getCollaboratorPermissionLevel = async () => { throw new Error('403'); };
  await assert.rejects(h.evaluate(), /403/);
  assert.equal(h.state.writes.filter(write => write.kind === 'check').length, 0);
});

test('status routing supports multiple PRs but excludes closed, stale, and other repositories', async () => {
  const h = harness();
  h.statusEvent();
  h.state.associated = [
    h.state.pr, { ...h.state.pr, number: 611 },
    { ...h.state.pr, number: 612, state: 'closed' },
    { ...h.state.pr, number: 613, head: { sha: OLD_SHA } },
    { ...h.state.pr, number: 614, base: { repo: { full_name: 'other/repo' } } },
  ];
  assert.deepEqual(await findPullRequests(h), [610, 611]);
  h.context.payload.sender = MEMBER;
  assert.deepEqual(await findPullRequests(h), []);
});

test('non-PR comments and arbitrary events are ignored', () => {
  const h = harness();
  h.command('MEMBER');
  h.context.payload.issue = { number: 610 };
  assert.equal(requestKind(h.context), null);
  h.context.eventName = 'push';
  assert.equal(requestKind(h.context), null);
});

test('CodeRabbit comments on the conversation are not CI requests', () => {
  const h = harness();
  h.context.eventName = 'issue_comment';
  h.context.payload = {
    action: 'edited', issue: { number: 610, pull_request: {} }, sender: RABBIT,
    comment: { user: RABBIT, body: 'No actionable comments were generated in the recent review. 🎉' },
  };
  assert.equal(requestKind(h.context), null);
});

test('formal approvals and the removed approval relay never trigger CI', async () => {
  for (const [eventName, payload] of [
    ['pull_request_review', { action: 'submitted', sender: RABBIT, pull_request: { number: 610 },
      review: { user: RABBIT, state: 'approved', commit_id: SHA } }],
    ['workflow_run', { action: 'completed', workflow_run: { name: 'CodeRabbit Approval',
      path: '.github/workflows/coderabbit-approval.yml', event: 'pull_request_review',
      conclusion: 'success', head_sha: SHA, pull_requests: [{ number: 610 }] } }],
  ]) {
    const h = harness();
    Object.assign(h.context, { eventName, payload });
    assert.deepEqual(await findPullRequests(h), []);
    assert.equal((await h.evaluate()).should_run, 'false');
    assert.equal(h.state.writes.length, 0);
  }
});
