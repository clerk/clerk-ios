# Remote devices

A machine that is not a Mac cannot run an iOS simulator. There the CLI starts a job on a GitHub Actions runner through `.github/workflows/verify-remote.yml`. The job puts E2EHost on a simulator and opens a tunnel, and the CLI drives the simulator through that tunnel. The job is called a session. The runner and the tunnel never get the Platform API key or the instance's secret key.

## What the machine needs

- Node 24. On any other Node major, the CLI reruns itself under `node@24` through `npx` and prints a `note` line that says so.
- A GitHub token in `GH_TOKEN` or `GITHUB_TOKEN`, or a logged-in `gh`. The token must be able to read the repository over REST.
- Permission to dispatch `verify-remote.yml`.
- Permission to `git push` your own branch, if you want to verify a commit that you make on this machine. Without it you can still verify commits that GitHub already has.
- Network access to `api.github.com`, `*.trycloudflare.com`, `api.clerk.com`, and `*.clerk.accounts.dev`.
- A Clerk Platform API credential. In a cloud environment, add an API credential for `api.clerk.com` with path prefix `/v1/platform/`. The environment then adds the key after a request leaves the machine, and no key is ever in the session.

`doctor` checks each of these and prints the fix. `doctor --live` then proves the path end to end, as `SKILL.md` describes under Doctor.

A cloud environment can install `gh` once, in its setup script, so that a session does not have to. `attach` needs a `gh` whose `gh pr edit` has `--attach`, which is 2.99.0 or newer:

```bash
#!/bin/bash
if ! gh pr edit --help 2>/dev/null | grep -q -- --attach; then
  V=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/cli/cli/releases/latest | sed -n 's|.*/tag/v||p')
  case "$V" in [0-9]*.[0-9]*.[0-9]*) ;; *) V=2.102.0 ;; esac
  curl -fsSL "https://github.com/cli/cli/releases/download/v${V}/gh_${V}_linux_amd64.tar.gz" | tar -xz -C /tmp \
    && install -m 0755 "/tmp/gh_${V}_linux_amd64/bin/gh" /usr/local/bin/gh \
    || echo "setup: gh ${V} install failed"
fi
gh --version || true
```

Without it, `doctor` reports `gh-attach` with its fix, and `attach` hands the evidence to the session's runner, as described below.

## What a session builds

A session builds a commit that GitHub has. `up` and `run` fail with `BUILD_FAILED` when GitHub does not have HEAD, and the fix is to push. The app sources are the build inputs that `SKILL.md` lists under Launch.

When the app sources differ from HEAD, `up` and `run` send the difference as one patch: `git diff --binary HEAD` of the app sources, with new files that git does not ignore. The session resets its checkout to the commit, applies the patch, builds, and installs the app on the same simulator. Edits to a tracked file are sent even when the file matches an ignore rule. When the patch does not apply, the build fails with `BUILD_FAILED` and says so; commit and push the changes, then run again. The patch is at most 16 MiB. The session refuses a patch that changes a file outside the app sources. It also refuses any patch when the session runs on `main`, so work on a branch to send uncommitted changes.

A run on such a build is not tied to a commit. Its `run.json` names the patch under `remote.builtPatch`, and `attach` refuses it, as the run and as a before run. Commit and push the change, `run` again, and attach that run. After a session builds a patch, it stores nothing for later sessions: no app, no XCTest runner, and no Swift packages.

While the session builds, `up` and `run` print each new line of the build output, after `build   |`.

`up` starts the session's run on your branch as GitHub has it. The run builds only the commit it was started on, or a later commit of that branch. When HEAD is not on that branch on GitHub, or is behind it, the run fails at the step `Read the request` and no session starts. Push or pull, then run `up` again. A detached HEAD has no branch, so `doctor` and `up` fail until you switch to a branch that GitHub has.

After you push an edit to the app, `run` asks the same session to build the new commit, with no patch. The session builds it only when GitHub shows it as a later commit of the branch the session was started on. After a rebase or an amend, the pushed commit is not a later commit of that branch, and the build fails with `BUILD_FAILED`. Run `down`, then `up`. The session keeps its build directory, so a small edit builds incrementally. Specs run from your working tree, so an edit to a spec needs no commit. A session that already holds the build for your app sources is reused as it is.

A session builds nothing when CI already built the app. It names the app by a key made from the app sources at the commit, the package versions that Xcode resolves for it, the Xcode and simulator SDK builds, and the build command. When an app with that key is stored, the session installs it. `verify-app-cache.yml` stores one for each push to `main` that changes the app sources and once a week, and a session stores the app it builds. A run on a branch finds what that branch stored and what `main` stored, and nothing of other branches. A stored app that nothing reads for 7 days is gone. Every session restores the build state that `main` stored, so the first build of a change is incremental, also in a session that installed a stored app. A build is still slow for several minutes after the ready line, while the simulator finishes its first boot. When no app is stored, the session builds and only then boots the simulator, because on this runner a build is three to four times slower during the first boot of a simulator. A one-file change then builds in under a minute. The `build` line of `up` gives the seconds of the install or of the build and install. The job log has one line, `verify-remote stages`, with the time of each stage.

## Runners and cost

The default runner label is `xcode-27`, a GitHub-hosted Mac that costs nothing for a public repository. It has Xcode 27 and an `iPhone Air` simulator on iOS 27.0, and it is slow. Plan for 7 to 10 minutes before the first spec runs. The session's 60 minutes start when the runner starts. The workflow names the iOS runtime it uses, `IOS_RUNTIME` in `verify-remote.yml`. On a runner without that runtime, the session fails at `Pick the simulator`, and the step lists the iOS runtimes the runner has.

`--runner blacksmith-6vcpu-macos-27` uses a Blacksmith runner instead, which is ready in about three minutes and is billed by the minute. `verify-remote.yml` starts a session only on `xcode-27`, `ubuntu-latest` (where the session of `doctor --live` runs), or `blacksmith-6vcpu-macos-27`, and fails its first job for any other label. To add a label, add it to the `Check the runner label` step there; it needs a Mac with Xcode and the iOS runtime that `IOS_RUNTIME` names. A held session keeps its label, and `--runner` with another label fails until `down`. The CLI ends a session that is not ready 40 minutes after it asked for the build, and `up` then fails with `NOT_READY`.

If a run publishes no tunnel within 20 minutes, `up` fails with `NOT_READY`, says whether the run is still queued, and gives its URL. While a run has not published its tunnel, the CLI prints a `wait` line that names the label it is waiting for and for how long:

```console
wait    run <run> has waited 15s, now for a xcode-27 runner
wait    run <run> has waited 85s, now for the tunnel on xcode-27
```

## Session lifetime

A session stops itself after 15 minutes without a call from the CLI, and always 60 minutes after it started. `VERIFY_REMOTE_IDLE_MINUTES` (1 to 120) and `VERIFY_REMOTE_CAP_MINUTES` (2 to 360) change the limits for sessions you start. `down` stops the session at once.

After an idle stop, the next `up` or `run` prints a `lost` line that ends in `renewing` and starts a new session. A session with under two minutes left before its cap is replaced the same way, with an `ending` line.

When the checkout holds no lease, `up` and `run` end any session of this checkout that is still running, and `down --stale` does so at any time. The idle stop ends whatever they miss, such as the session of a checkout that was deleted.

## Evidence from a machine that cannot attach

`attach` always tries `gh pr edit --attach` itself first, on every kind of machine, and hands off only when that cannot work. The hand-off sends the evidence of a remote run to the session's runner. It sends the files that the flags of `attach` chose from the sealed run directory, with a manifest that names the run, the pull request, the device, the commit, and each file's size and SHA-256. With `--before`, the manifest also names the before run, its commit, and its counts, and the hand-off carries one file of the before run for each file of the run. Those files come from the before run's directory in this checkout, whichever session made that run. When that directory is gone, as it is in a new sandbox, `attach` fails with `USAGE` before it sends anything, and its fix is to attach without `--before` and name the before run in the PR. The files travel over the session's tunnel, with the session's token, in pieces of 1 MiB. The session job keeps them in one directory and uploads that directory as the artifact `verify-evidence` when the job ends. The artifact holds nothing else of the session.

`.github/workflows/verify-attach.yml` then runs, from the default branch. It downloads the artifact, checks every file against the manifest and against its own limits, and puts the block in the description with `gh pr edit --attach`. It holds a file of the before run to the same checks as a file of the run. It writes the description twice, as `attach` does: the first write uploads the files as a list, and the second lays them out in the tables that `SKILL.md` describes under Evidence. For the second write it reads the addresses of the uploads from the block, and takes only addresses of GitHub uploads. If the pull request or the block changed between the two writes, it leaves the list and says so in its run. A rerun of that job uploads the files again and lays them out. The tables take about twice the characters of the list, so in a description near GitHub's limit of 65,536 characters the second write can fail after the first one succeeded. The job then fails, and the list stays until the description is shorter and the job runs again. It never runs anything from the branch or from the artifact. The workflow did not run the tests, so the line it writes says that the session reported the result, links the session's run in the Actions tab, and names the account that started that run, as GitHub records it. With a before run, the line says that the session reports that run, and it links the commit of that run so that a reader can open it.

The repository needs this set up once:

1. `verify-remote.yml`, `verify-attach.yml`, and `.github/scripts/verify-attach.mjs` are on the default branch. GitHub starts `verify-attach.yml` only from there, so until then a hand-off succeeds and nothing is published.
2. A machine account has write access to the repository.
3. That account has a fine-grained personal access token that is limited to this repository and has the permission "Pull requests: read and write".
4. The repository has an environment named `verify-evidence`, and its deployment branches are limited to the default branch.
5. The token is the secret `VERIFY_EVIDENCE_TOKEN` of that environment. The repository has no repository secret of that name.

Do not store the token as a repository secret. Anyone who can push a branch can add a workflow to it, and a workflow on any branch can read a repository secret. A secret of an environment that allows only the default branch reaches only jobs that run on the default branch, and the job of `verify-attach.yml` is one.

Without the environment or its secret, the workflow prints a notice and publishes nothing.

The workflow publishes only when all of these hold. Otherwise it prints the reason in its run and publishes nothing.

- The pull request that `--pr` names is open, and its branch is in this repository, not in a fork.
- Its branch is the branch the session was started on.
- The commit the run was made at is one of the pull request's commits.
- The commit that branch had when `up` started the session is one of them too, or a commit that the base branch of the pull request holds, such as the commit the branch came from. The workflow asks GitHub to compare that commit with the base of the pull request. GitHub lists the first 250 commits of a pull request, and the workflow reads no further. When a longer pull request has either commit past the first 250, the workflow says so and publishes nothing. Squash or rebase the branch to 250 commits or fewer, or attach from a machine whose `gh` can attach.
- With `--before`, the commit of the before run is the commit of the run or a commit before it in its history. The workflow asks GitHub to compare the two commits.
- The hand-off has at least one file.
- The description has the two evidence comments of the platform once each, or neither.
- A description without the comments does not end inside a code fence that is never closed.

`attach` checks the same rules before it sends anything, and fails with the reason.

So one session does both runs: push the branch, `up`, `run` for the before run, push the change, `run` again, open the pull request, `attach` with `--before <run-id>`, `down`. Open the pull request after the last run, so that it is not left open without its evidence, which reaches the description about a minute after `down`.

A before run is the build without the change, so its commit is often the one the branch started from, which is no commit of the pull request. The workflow therefore does not look for that commit among the commits of the pull request. It asks GitHub whether that commit is the commit of the run or a commit before it in its history, and it publishes nothing when the answer is no. After a rebase that rewrote the commit of the before run, `run` the spec again on a commit that the branch still has, and pass that run as `--before`. The workflow cannot check that the files of the before run came from a build of that commit, which is why the line says that the session reports the before run.

The manifest of a hand-off has a version, and the workflow publishes only the version of the script on the default branch. A branch whose verify code is older than the default branch's hands off a manifest that the workflow refuses. The refusal names both versions in the run of `verify-attach`, and nothing on the pull request shows it. Merge the default branch into the branch before you `attach`, then `down`, `up`, `run`, and `attach`. A session takes only the version of its own code. When the checkout changed version after `up`, `attach` fails, names both versions, and says to `down` and `up`.

A push after the run does not lose the evidence. The line in the block names the commit the run was made at, and when the pull request has moved on it ends with "The pull request has newer commits." To show the newer commit, `run` again and `attach` again in the same session, which replaces the block. The session builds the new commit, and no new session is needed. After a rewrite of the branch's history that removes either commit, `down` and `up` before the next `run`.

A hand-off holds one video of up to 100 MiB and screenshots of up to 10 MiB each, with at most 50 files and 150 MiB in all. A before run adds one more video and as many screenshots as the run has, and its files count toward the 50 files and the 150 MiB. A session keeps one hand-off, and a later `attach` in the same session replaces it. `down` gives a session that holds evidence up to five minutes to upload it before it cancels the run.

The runs of `verify-attach` for one branch take turns, and each one publishes.

The workflow reads the description again just before it writes. An edit that someone saves after that read, and before `gh` has uploaded the files and written the description, is overwritten. That is a few seconds for screenshots and up to a few minutes for a large video. `attach` on a machine whose `gh` can attach has the same window.

If the description has no evidence a few minutes after `down`, read the newest run of `verify-attach` in the Actions tab of the repository. It says what it refused and why.

## Network and proxy

The CLI goes through `HTTPS_PROXY` when the direct path to GitHub does not work, and `doctor` prints the choice and the reason in `remote-env`.

The `tunnel-egress` and `clerk-egress` checks in `doctor` show a host that the environment blocks as `blocked:` and what answered, or as `no response from <host>`. When `api.github.com` does not answer, the `github-rest` check shows `api.github.com did not answer`. For the two egress checks, the fix is to add the host to the allowed domains of the environment that the CLI runs in. For `github-rest`, which reports any failed request this way, timeouts included, first check that `api.github.com` is an allowed domain; if it already is, look at the network or the proxy; the check's fix line also says what GitHub access a cloud session needs.

## GitHub access

A session uses GitHub in two ways. REST starts, reads, and ends sessions. `git push` gets a commit that you make to GitHub, so that the session can build it.

Claude Code cloud sessions are one example of a sandbox where the two differ. REST there can use a different credential from `git push`, so REST can work while a push is refused. A 403 on push means that this machine's GitHub credential may not push to the repository. In a cloud sandbox that credential belongs to the sandbox's GitHub integration, and an administrator of the organization gives the integration access to the repository. The sandbox's `GH_TOKEN` is a placeholder that only the sandbox's proxy turns into a real credential, which is the case above where GitHub rejects the token on a direct connection.
