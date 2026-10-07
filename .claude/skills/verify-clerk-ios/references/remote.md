# Remote devices

A machine that is not a Mac cannot run an iOS simulator. There the CLI starts a job on a GitHub Actions runner through `.github/workflows/verify-remote.yml`. The job boots a simulator, builds E2EHost, and opens a tunnel, and the CLI drives the simulator through that tunnel. The job is called a session. The runner and the tunnel never get the Platform API key or the instance's secret key.

## What the machine needs

- Node 24. On any other Node major, the CLI reruns itself under `node@24` through `npx` and prints a `note` line that says so.
- A GitHub token in `GH_TOKEN` or `GITHUB_TOKEN`, or a logged-in `gh`. The token must be able to read the repository over REST.
- Permission to dispatch `verify-remote.yml`.
- Permission to `git push` your own branch, if you want to verify a commit that you make on this machine. Without it you can still verify commits that GitHub already has.
- Network access to `api.github.com`, `*.trycloudflare.com`, `api.clerk.com`, and `*.clerk.accounts.dev`.
- A Clerk Platform API credential. In a cloud environment, add an API credential for `api.clerk.com` with path prefix `/v1/platform/`. The environment then adds the key after a request leaves the machine, and no key is ever in the session.

`doctor` checks each of these and prints the fix. `doctor --live` then proves the path end to end, as `SKILL.md` describes under Doctor.

## What a session builds

A session builds a commit that GitHub has, never your working tree. `up` and `run` fail with `BUILD_FAILED` when the app sources have uncommitted changes or when GitHub does not have HEAD, and the fix is to commit and push. The app sources are the build inputs that `SKILL.md` lists under Launch.

`up` starts the session's run on your branch as GitHub has it. The run builds only the commit it was started on, or a later commit of that branch. When HEAD is not on that branch on GitHub, or is behind it, the run fails at the step `Read the request` and no session starts. Push or pull, then run `up` again.

After you push an edit to the app, `run` asks the same session to build the new commit. The session builds it only when GitHub shows it as a later commit of the branch the session was started on. After a rebase or an amend, the pushed commit is not a later commit of that branch, and the build fails with `BUILD_FAILED`. Run `down`, then `up`. The session keeps its build directory, so a small edit rebuilds in seconds. Specs run from your working tree, so an edit to a spec needs no commit. A session that already holds the build for your app sources is reused as it is.

## Runners and cost

The default runner label is `xcode-27`, a GitHub-hosted Mac that costs nothing for a public repository. It has Xcode 27 and an `iPhone Air` simulator on iOS 27.0, and it is slow. Plan for 15 to 20 minutes before the first spec runs. The session's 60 minutes start when the runner starts. The workflow names the iOS runtime it uses, `IOS_RUNTIME` in `verify-remote.yml`. On a runner without that runtime, the session fails at `Pick the simulator`, and the step lists the iOS runtimes the runner has.

`--runner blacksmith-6vcpu-macos-27` uses a Blacksmith runner instead, which is ready in about three minutes and is billed by the minute. A held session keeps its label, and `--runner` with another label fails until `down`. The CLI ends a session that is not ready 40 minutes after it asked for the build, and `up` then fails with `NOT_READY`.

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

`attach` always tries `gh pr edit --attach` itself first, on every kind of machine, and hands off only when that cannot work. The hand-off sends the evidence of a remote run to the session's runner. It sends the video and the screenshots from the sealed run directory, with a manifest that names the run, the pull request, the device, the commit, and each file's size and SHA-256. The files travel over the session's tunnel, with the session's token, in pieces of 1 MiB. The session job keeps them in one directory and uploads that directory as the artifact `verify-evidence` when the job ends. The artifact holds nothing else of the session.

`.github/workflows/verify-attach.yml` then runs, from the default branch. It downloads the artifact, checks every file against the manifest and against its own limits, and puts the block in the description with `gh pr edit --attach`. It never runs anything from the branch or from the artifact. The workflow did not run the tests, so the line it writes says that the session reported the result, links the session's run in the Actions tab, and names the account that started that run, as GitHub records it.

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
- The commit that branch had when `up` started the session is one of them too. GitHub lists the first 250 commits of a pull request, and the workflow reads no further. When a longer pull request has either commit past the first 250, the workflow says so and publishes nothing. Squash or rebase the branch to 250 commits or fewer, or attach from a machine whose `gh` can attach.
- The hand-off has at least one file.
- The description has the two evidence comments of the platform once each, or neither.
- A description without the comments does not end inside a code fence that is never closed.

`attach` checks the same rules before it sends anything, and fails with the reason.

A push after the run does not lose the evidence. The line in the block names the commit the run was made at, and when the pull request has moved on it ends with "The pull request has newer commits." To show the newer commit, `run` again and `attach` again in the same session, which replaces the block. The session builds the new commit, and no new session is needed. After a rewrite of the branch's history that removes either commit, `down` and `up` before the next `run`.

A hand-off holds one video of up to 100 MiB and screenshots of up to 10 MiB each, with at most 50 files and 150 MiB in all. A session keeps one hand-off, and a later `attach` in the same session replaces it. `down` gives a session that holds evidence up to five minutes to upload it before it cancels the run.

The runs of `verify-attach` for one branch take turns, and each one publishes.

The workflow reads the description again just before it writes. An edit that someone saves after that read, and before `gh` has uploaded the files and written the description, is overwritten. That is a few seconds for screenshots and up to a few minutes for a large video. `attach` on a machine whose `gh` can attach has the same window.

If the description has no evidence a few minutes after `down`, read the newest run of `verify-attach` in the Actions tab of the repository. It says what it refused and why.

## Network and proxy

The CLI goes through `HTTPS_PROXY` when the direct path to GitHub does not work, and `doctor` prints the choice and the reason in `remote-env`.

A host that the environment blocks shows in `doctor` as `blocked:` and what answered. The fix is to add the host to the allowed domains of the environment that the CLI runs in.

## GitHub access

A session uses GitHub in two ways. REST starts, reads, and ends sessions. `git push` gets a commit that you make to GitHub, so that the session can build it.

Claude Code cloud sessions are one example of a sandbox where the two differ. REST there uses the session user's own access. `git push` needs the Claude GitHub App installed on the repository, and a 403 on push means that it is not. The sandbox's `GH_TOKEN` is a placeholder that only the sandbox's proxy turns into a real credential, which is the case above where GitHub rejects the token on a direct connection.
