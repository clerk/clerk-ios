const COMMAND = /^\s*\/run\s+ci\s*$/im;
const MEMBER_ASSOCIATIONS = new Set(['MEMBER', 'OWNER']);
const WAITING_STATUSES = new Set(['queued', 'requested', 'waiting', 'pending']);
const PUSH_ACTIONS = new Set(['opened', 'synchronize', 'reopened', 'ready_for_review']);

function requestKind(context) {
  const { payload, eventName } = context;
  if (eventName === 'pull_request_target') {
    return PUSH_ACTIONS.has(payload.action) ? 'automatic' : null;
  }
  if (eventName !== 'issue_comment' || !payload.issue?.pull_request) return null;
  const { comment, action } = payload;
  return action === 'created' && COMMAND.test(comment.body) ? 'comment command' : null;
}

async function findPullRequests({ github, context }) {
  if (!requestKind(context)) return [];
  const { eventName, payload } = context;
  return [eventName === 'issue_comment' ? payload.issue.number : payload.pull_request.number];
}

// The workflow token can't see private organization membership, so a private
// member's association reads as COLLABORATOR. Treat writers who aren't outside
// collaborators as internal, which works regardless of membership visibility.
async function internalWriterIssue(github, repo, login) {
  const { data: access } = await github.rest.repos.getCollaboratorPermissionLevel({ ...repo, username: login });
  const writeRoles = new Set(['write', 'push', 'maintain', 'admin']);
  if (!writeRoles.has(access.permission) && !writeRoles.has(access.role_name)) {
    return 'does not have write access';
  }
  const outsiders = await github.paginate(github.rest.repos.listCollaborators, {
    ...repo, affiliation: 'outside', per_page: 100,
  });
  if (outsiders.some(user => user.login.toLowerCase() === login.toLowerCase())) {
    return 'is an outside collaborator';
  }
  return null;
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
    if (pr.draft || pr.user.type !== 'User') {
      return skip('automatic CI requires a ready PR authored by a Clerk organization member.');
    }
    if (!MEMBER_ASSOCIATIONS.has(pr.author_association)) {
      const issue = await internalWriterIssue(github, repo, pr.user.login);
      if (issue) return skip(`automatic CI requires a Clerk organization member, and the PR author ${issue}.`);
    }
    // A newer push's run claims its own commit. A cancelled run that claimed it
    // would mark that commit's Manual CI as cancelled.
    if (context.payload.pull_request.head.sha !== headSha) return skip('a newer commit was pushed.');
  } else if (!MEMBER_ASSOCIATIONS.has(context.payload.comment.author_association)) {
    return skip('the command author is not a Clerk organization member.');
  }

  const checks = (await github.paginate(github.rest.checks.listForRef, {
    ...repo, ref: headSha, check_name: 'Manual CI', filter: 'all', per_page: 100,
  })).filter(check => check.app?.slug === 'github-actions');
  const latest = [...checks].sort((a, b) => b.id - a.id)[0];
  const runUrl = `${context.serverUrl}/${repo.owner}/${repo.repo}/actions/runs/${context.runId}`;
  if (latest?.status === 'in_progress') return skip('CI is already running for this commit.');
  if (latest && !WAITING_STATUSES.has(latest.status) && latest.status !== 'completed') {
    return skip(`CI has unexpected status '${latest.status}'.`);
  }
  // The PR may have changed while we read its checks.
  const { data: current } = await github.rest.pulls.get(prParams);
  if (current.state !== 'open' || current.head.sha !== headSha || (automatic && current.draft)) {
    return skip('the PR changed while resolving this request.');
  }

  const checkData = {
    ...repo, status: 'in_progress', details_url: runUrl, started_at: new Date().toISOString(),
    output: {
      title: 'Manual CI',
      summary: automatic ? 'CI started automatically for the latest push.'
        : `CI requested by ${context.payload.sender.login}.`,
    },
  };
  const { data: check } = latest && WAITING_STATUSES.has(latest.status)
    ? await github.rest.checks.update({ ...checkData, check_run_id: latest.id })
    : await github.rest.checks.create({ ...checkData, name: 'Manual CI', head_sha: headSha });
  core.setOutput('manual_check_run_id', check.id);
  core.setOutput('base_ref', current.base.ref);
  core.setOutput('head_repository', pr.head.repo.full_name);
  core.setOutput('head_sha', headSha);
  core.setOutput('should_run', 'true');
  core.info(`Accepted ${kind} for PR #${prNumber} at ${headSha}.`);
}

module.exports = { findPullRequests, requestKind, resolveRequest };
