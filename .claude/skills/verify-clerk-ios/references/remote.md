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

After you push an edit to the app, `run` asks the same session to build the new commit. The session keeps its build directory, so a small edit rebuilds in seconds. Specs run from your working tree, so an edit to a spec needs no commit. A session that already holds the build for your app sources is reused as it is.

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

## Network and proxy

The CLI goes through `HTTPS_PROXY` when the direct path to GitHub does not work, and `doctor` prints the choice and the reason in `remote-env`.

A host that the environment blocks shows in `doctor` as `blocked:` and what answered. The fix is to add the host to the allowed domains of the environment that the CLI runs in.

## GitHub access

A session uses GitHub in two ways. REST starts, reads, and ends sessions. `git push` gets a commit that you make to GitHub, so that the session can build it.

Claude Code cloud sessions are one example of a sandbox where the two differ. REST there uses the session user's own access. `git push` needs the Claude GitHub App installed on the repository, and a 403 on push means that it is not. The sandbox's `GH_TOKEN` is a placeholder that only the sandbox's proxy turns into a real credential, which is the case above where GitHub rejects the token on a direct connection.
