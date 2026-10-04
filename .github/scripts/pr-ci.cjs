const INSTRUCTIONS_MARKER = '<!-- clerk-ios-manual-ci -->';
const STARTED_MARKER = '<!-- clerk-ios-pr-ci-started -->';
const COMMAND = /^\s*\/run\s+ci\s*$/im;
const CHECKBOX = /^- \[[xX]\] Run CI\s*$/m;
const MEMBER_ASSOCIATIONS = new Set(['MEMBER', 'OWNER']);
const WAITING_STATUSES = new Set(['queued', 'requested', 'waiting', 'pending']);
const RELAY_PATH = '.github/workflows/coderabbit-review-activity.yml';

function isCodeRabbit(user) {
  return user?.id === 136622811 && user.login === 'coderabbitai[bot]' && user.type === 'Bot';
}

function isCodeRabbitAuthor(author) {
  return author?.__typename === 'Bot' && author.login === 'coderabbitai';
}

function isActionsBot(user) {
  return user?.id === 41898282 && user.login === 'github-actions[bot]' && user.type === 'Bot';
}

function requestKind(context) {
  const { payload, eventName } = context;
  if (eventName === 'status') {
    return isCodeRabbit(payload.sender) && payload.context === 'CodeRabbit'
      && payload.state === 'success' && payload.description === 'Review completed'
      ? 'automatic' : null;
  }
  if (eventName === 'pull_request_target') {
    return payload.action === 'ready_for_review' ? 'automatic' : null;
  }
  // CodeRabbit often resolves its threads after its status turns green, and GitHub
  // has no workflow event for resolving a thread. Its review comment activity is
  // relayed here as a hint to re-evaluate; the relay itself is never trusted.
  if (eventName === 'workflow_run') {
    const run = payload.workflow_run;
    return run?.path === RELAY_PATH && run.event === 'pull_request_review_comment'
      && run.conclusion === 'success' ? 'automatic' : null;
  }
  if (eventName !== 'issue_comment' || !payload.issue?.pull_request) return null;
  const { comment, action } = payload;
  if (action === 'created' && COMMAND.test(comment.body)) return 'comment command';
  if (action === 'edited' && isActionsBot(comment.user)
    && comment.body.includes(INSTRUCTIONS_MARKER) && CHECKBOX.test(comment.body)) return 'checkbox';
  return null;
}

async function hasUnresolvedCodeRabbitThreads(github, repo, prNumber) {
  let cursor = null;
  do {
    const { repository } = await github.graphql(`query($owner: String!, $repo: String!, $number: Int!, $cursor: String) {
      repository(owner: $owner, name: $repo) {
        pullRequest(number: $number) {
          reviewThreads(first: 100, after: $cursor) {
            nodes { isResolved comments(first: 1) { nodes { author { __typename login } } } }
            pageInfo { hasNextPage endCursor }
          }
        }
      }
    }`, { owner: repo.owner, repo: repo.repo, number: prNumber, cursor });
    const threads = repository.pullRequest.reviewThreads;
    if (threads.nodes.some(thread => !thread.isResolved && isCodeRabbitAuthor(thread.comments.nodes[0]?.author))) {
      return true;
    }
    cursor = threads.pageInfo.hasNextPage ? threads.pageInfo.endCursor : null;
  } while (cursor);
  return false;
}

async function findPullRequests({ github, context }) {
  if (!requestKind(context)) return [];
  const { eventName, payload, repo } = context;
  if (eventName === 'issue_comment') return [payload.issue.number];
  if (eventName === 'pull_request_target') return [payload.pull_request.number];
  const sha = eventName === 'workflow_run' ? payload.workflow_run.head_sha : payload.sha;
  const prs = await github.paginate(github.rest.repos.listPullRequestsAssociatedWithCommit, {
    ...repo, commit_sha: sha, per_page: 100,
  });
  return [...new Set(prs.filter(pr => pr.state === 'open' && pr.head.sha === sha
    && pr.base.repo.full_name.toLowerCase() === `${repo.owner}/${repo.repo}`.toLowerCase())
    .map(pr => pr.number))];
}

async function resolveRequest({ github, context, core, prNumber }) {
  core.setOutput('should_run', 'false');
  const skip = reason => core.info(`Skipping PR #${prNumber}: ${reason}`);
  const kind = requestKind(context);
  if (!kind) return skip('not a CI request.');
  const repo = context.repo;
  const prParams = { ...repo, pull_number: prNumber };
  const { data: pr } = await github.rest.pulls.get(prParams);
  if (pr.state !== 'open' || !pr.head.repo) return skip('PR is closed or its head repository is unavailable.');
  const headSha = pr.head.sha;
  const automatic = kind === 'automatic';

  if (automatic) {
    if (pr.draft || pr.user.type !== 'User' || !MEMBER_ASSOCIATIONS.has(pr.author_association)) {
      return skip('automatic CI requires a ready PR authored by a Clerk organization member.');
    }
    if (context.eventName === 'status' && context.payload.sha !== headSha) {
      return skip('the completed review belongs to an older commit.');
    }
  } else if (kind === 'comment command') {
    if (!MEMBER_ASSOCIATIONS.has(context.payload.comment.author_association)) {
      return skip('the command author is not a Clerk organization member.');
    }
  } else {
    // Reset the existing quick action, retaining its original access policy.
    const { comment, sender } = context.payload;
    await github.rest.issues.updateComment({
      ...repo, comment_id: comment.id, body: comment.body.replace(CHECKBOX, '- [ ] Run CI'),
    });
    if (sender.type !== 'User') return skip('the checkbox editor is not a GitHub user.');
    const { data: access } = await github.rest.repos.getCollaboratorPermissionLevel({
      ...repo, username: sender.login,
    });
    const writeRoles = new Set(['write', 'push', 'maintain', 'admin']);
    if (!writeRoles.has(access.permission) && !writeRoles.has(access.role_name)) {
      return skip('the checkbox editor does not have write access.');
    }
    const outsiders = await github.paginate(github.rest.repos.listCollaborators, {
      ...repo, affiliation: 'outside', per_page: 100,
    });
    if (outsiders.some(user => user.login.toLowerCase() === sender.login.toLowerCase())) {
      return skip('the checkbox editor is an outside collaborator.');
    }
  }

  const comments = await github.paginate(github.rest.issues.listComments, {
    ...repo, issue_number: prNumber, per_page: 100,
  });
  const alreadyStarted = comments.some(comment => isActionsBot(comment.user)
    && comment.body.startsWith(STARTED_MARKER));
  if (automatic && alreadyStarted) return skip('CI has already started once; further runs are manual.');

  if (automatic) {
    // A green status alone also follows reviews with findings, so additionally
    // require that every review thread CodeRabbit opened has been resolved.
    const statuses = await github.paginate(github.rest.repos.listCommitStatusesForRef, {
      ...repo, ref: headSha, per_page: 100,
    });
    const status = statuses.filter(status => status.context === 'CodeRabbit' && isCodeRabbit(status.creator))
      .sort((a, b) => b.id - a.id)[0];
    if (status?.state !== 'success' || status.description !== 'Review completed') {
      return skip('CodeRabbit has not completed its review of the current commit.');
    }
    if (await hasUnresolvedCodeRabbitThreads(github, repo, prNumber)) {
      return skip('CodeRabbit has unresolved review threads.');
    }
  }

  const listChecks = async sha => (await github.paginate(github.rest.checks.listForRef, {
    ...repo, ref: sha, check_name: 'Manual CI', filter: 'all', per_page: 100,
  })).filter(check => check.app?.slug === 'github-actions');
  const checks = await listChecks(headSha);
  const latest = [...checks].sort((a, b) => b.id - a.id)[0];
  const runUrl = `${context.serverUrl}/${repo.owner}/${repo.repo}/actions/runs/${context.runId}`;
  const rememberStart = async (sha, url, source) => {
    if (alreadyStarted) return;
    // Keep this separate from the instructions comment, which is reset on pushes.
    // The shared PR concurrency group serializes this claim with manual requests.
    await github.rest.issues.createComment({
      ...repo, issue_number: prNumber,
      body: `${STARTED_MARKER}\nCI was first started for \`${sha}\` (${source}). [View CI run](${url}).\n\n`
        + 'Further pushes and retries require `/run ci` or the **Run CI** checkbox. This PR will not start CI automatically again.',
    });
  };

  if (automatic) {
    // Account for manual/release runs predating this workflow, including older
    // commits. A queued placeholder is not a kickoff. The marker survives even
    // force-pushes that subsequently remove those commits from the PR.
    let previous = checks.find(check => ['in_progress', 'completed'].includes(check.status));
    if (!previous) {
      const commits = await github.paginate(github.rest.pulls.listCommits, { ...prParams, per_page: 100 });
      for (const commit of commits) {
        if (commit.sha === headSha) continue;
        previous = (await listChecks(commit.sha)).find(check => ['in_progress', 'completed'].includes(check.status));
        if (previous) break;
      }
    }
    if (previous) {
      await rememberStart(previous.head_sha, previous.details_url || runUrl, 'previous CI kickoff');
      return skip('CI already ran before this request; further runs are manual.');
    }
  }

  if (latest?.status === 'in_progress') return skip('CI is already running for this commit.');
  if (latest && !WAITING_STATUSES.has(latest.status) && latest.status !== 'completed') {
    return skip(`CI has unexpected status '${latest.status}'.`);
  }
  // The PR may have changed while we read the review and historical checks.
  const { data: current } = await github.rest.pulls.get(prParams);
  if (current.state !== 'open' || current.head.sha !== headSha || (automatic && current.draft)) {
    return skip('the PR changed while resolving this request.');
  }

  await rememberStart(headSha, runUrl, automatic ? 'automatic after CodeRabbit\'s review was resolved' : kind);
  const checkData = {
    ...repo, status: 'in_progress', details_url: runUrl, started_at: new Date().toISOString(),
    output: {
      title: 'Manual CI',
      summary: automatic ? 'CI started automatically after CodeRabbit completed its review with all of its threads resolved.'
        : `CI requested by ${context.payload.sender.login}.`,
    },
  };
  const { data: check } = latest && WAITING_STATUSES.has(latest.status)
    ? await github.rest.checks.update({ ...checkData, check_run_id: latest.id })
    : await github.rest.checks.create({ ...checkData, name: 'Manual CI', head_sha: headSha });
  core.setOutput('manual_check_run_id', check.id);
  core.setOutput('head_repository', pr.head.repo.full_name);
  core.setOutput('head_sha', headSha);
  core.setOutput('should_run', 'true');
  core.info(`Accepted ${kind} for PR #${prNumber} at ${headSha}.`);
}

module.exports = { findPullRequests, requestKind, resolveRequest };
