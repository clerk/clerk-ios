const INSTRUCTIONS_MARKER = '<!-- clerk-ios-manual-ci -->';
const STARTED_MARKER = '<!-- clerk-ios-pr-ci-started -->';
const COMMAND = /^\s*\/run\s+ci\s*$/im;
const CHECKBOX = /^- \[[xX]\] Run CI\s*$/m;
const MEMBER_ASSOCIATIONS = new Set(['MEMBER', 'OWNER']);
const WAITING_STATUSES = new Set(['queued', 'requested', 'waiting', 'pending']);
const REVIEW_DECISIONS = new Set(['APPROVED', 'CHANGES_REQUESTED', 'DISMISSED']);

function isCodeRabbit(user) {
  return user?.id === 136622811 && user.login === 'coderabbitai[bot]' && user.type === 'Bot';
}

function isActionsBot(user) {
  return user?.id === 41898282 && user.login === 'github-actions[bot]' && user.type === 'Bot';
}

function requestKind(context) {
  const { payload, eventName } = context;
  if (eventName === 'workflow_run') {
    const run = payload.workflow_run;
    return payload.action === 'completed' && run?.name === 'CodeRabbit Approval'
      && run.path === '.github/workflows/coderabbit-approval.yml'
      && run.event === 'pull_request_review' && run.conclusion === 'success'
      ? 'automatic' : null;
  }
  if (eventName === 'status') {
    return isCodeRabbit(payload.sender) && payload.context === 'CodeRabbit'
      && payload.state === 'success' && payload.description === 'Review completed'
      ? 'automatic' : null;
  }
  if (eventName === 'pull_request_target') {
    return payload.action === 'ready_for_review' ? 'automatic' : null;
  }
  if (eventName !== 'issue_comment' || !payload.issue?.pull_request) return null;
  const { comment, sender, action } = payload;
  if (!['created', 'edited'].includes(action)) return null;
  if (action === 'created' && COMMAND.test(comment.body)) return 'comment command';
  if (action === 'edited' && isActionsBot(comment.user)
    && comment.body.includes(INSTRUCTIONS_MARKER) && CHECKBOX.test(comment.body)) return 'checkbox';
  return null;
}

async function findPullRequests({ github, context }) {
  if (!requestKind(context)) return [];
  if (context.eventName === 'issue_comment') return [context.payload.issue.number];
  if (context.eventName === 'pull_request_target') return [context.payload.pull_request.number];
  const run = context.payload.workflow_run;
  // The unprivileged approval workflow only wakes this trusted gate. Read the
  // actual approval and current PR state from GitHub; never consume its artifacts.
  if (run?.pull_requests?.length) return [...new Set(run.pull_requests.map(pr => pr.number))];
  // GitHub can omit pull_requests on fork workflow runs.
  const sha = run?.head_sha || context.payload.sha;
  if (!sha) return [];
  const prs = await github.paginate(github.rest.repos.listPullRequestsAssociatedWithCommit, {
    ...context.repo, commit_sha: sha, per_page: 100,
  });
  return [...new Set(prs.filter(pr => pr.state === 'open' && pr.head.sha === sha
    && pr.base.repo.full_name.toLowerCase() === `${context.repo.owner}/${context.repo.repo}`.toLowerCase())
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
    const reviews = await github.paginate(github.rest.pulls.listReviews, { ...prParams, per_page: 100 });
    // Thread replies use COMMENTED reviews and do not revoke an approval. A
    // later change request or dismissed approval must prevent automatic CI.
    const decision = reviews.filter(review => isCodeRabbit(review.user) && REVIEW_DECISIONS.has(review.state))
      .sort((a, b) => (b.submitted_at || '').localeCompare(a.submitted_at || '') || b.id - a.id)[0];
    if (decision?.state !== 'APPROVED' || decision.commit_id !== headSha) {
      return skip('CodeRabbit has not approved the current commit.');
    }
    // Explicit CodeRabbit approval commands can bypass its completed-review
    // requirement. Independently require completion on this exact commit.
    const statuses = await github.paginate(github.rest.repos.listCommitStatusesForRef, {
      ...repo, ref: headSha, per_page: 100,
    });
    const status = statuses.filter(status => status.context === 'CodeRabbit' && isCodeRabbit(status.creator))
      .sort((a, b) => b.id - a.id)[0];
    if (status?.state !== 'success' || status.description !== 'Review completed') {
      return skip('CodeRabbit has not completed its review of the current commit.');
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

  await rememberStart(headSha, runUrl, automatic ? 'automatic after CodeRabbit approval' : kind);
  const checkData = {
    ...repo, status: 'in_progress', details_url: runUrl, started_at: new Date().toISOString(),
    output: {
      title: 'Manual CI',
      summary: automatic ? 'CI started automatically after CodeRabbit reviewed and approved this commit.'
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
