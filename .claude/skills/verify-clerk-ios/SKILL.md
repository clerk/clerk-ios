---
name: verify-clerk-ios
description: Drive the clerk-ios SDK UI (AuthView, UserButton, UserProfileView, OrganizationSwitcher, session tasks) in the E2EHost app on an iOS simulator against a real Clerk development instance that the session creates and deletes, and capture video, screenshots, and host state as evidence. The simulator is a lane on this Mac, or a remote one on a CI runner when the machine is Linux. Use it to prove any change to ClerkKit, ClerkKitUI, or E2EHost works before calling it done, to reproduce a UI bug, or to run the golden regression specs.
---

# verify-clerk-ios

`.claude/skills/verify-clerk-ios/bin/control-clerk-ios` is a control CLI over [e2e](https://github.com/tester-army/e2e) 0.15.2 and `@e2e-dev/mobile` 0.9.0. It builds E2EHost, leases a simulator, creates one Clerk application for the worktree, puts its development instance on the settings each spec declares, seeds `+clerk_test` users, runs specs, and keeps the evidence. The application is this worktree's own and `down` deletes it. Read [Test instances](#test-instances) for where it comes from. On a Mac the simulator is a local lane. On any other machine it is a remote simulator on a CI runner; read [Remote simulator](#remote-simulator) first if you are on Linux. Run every command from the repo root. Add `.claude/skills/verify-clerk-ios/bin` to `PATH` (`export PATH="$PWD/.claude/skills/verify-clerk-ios/bin:$PATH"`) and you can type `control-clerk-ios` instead of the full path. Cursor also finds this skill through `.cursor/skills/verify-clerk-ios`, a symlink to this directory. Every verb takes `--json` and then prints one object. On success it is `{ "ok": true, "verb": "<verb>", ... }`, where `verb` names the verb and decides the remaining keys. On failure it is `{ "ok": false, "error": { "code", "message", "fix", "retryable" } }`. Exit codes are 0 for ok, 1 for spec failures, 2 for usage errors, and 3 for a failed precondition. Every error carries a `fix`.

The rule: no change to clerk-ios UI or auth behavior is done until a `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run` on the real host shows the changed behavior.

## Launch

```console
$ npm ci --prefix .claude/skills/verify-clerk-ios  # once per worktree, before anything else
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios doctor  # exits 3 until a build matches the current tree; on a clean machine build is the one failing check
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios up  # build E2EHost for this tree, create this worktree's Clerk application meanwhile, then lease verify-ios-<n> and install
wait    reading the team key from 1Password; approve the request in the 1Password app within 60s
backend local  this Mac runs the simulator itself
instances throwaway  1Password reaches the verification workspace org_3KHungJxbvIscuSvy8oos5MHAli
instance creating verify-throwaway-until-20261006t0607z-55385321 in org_3KHungJxbvIscuSvy8oos5MHAli
build   ios-3f9a1c2e07b1  local  building...
instance app_3KIVp105uKTccO9q5ofY0tRHXr3  up in 1.0s on standard, 212 settings match src/core/instances/base.json
clerk   Platform API: 5 requests by this command so far
clerk   Backend API on api.clerk.com
build   ios-3f9a1c2e07b1  local  built in 58s
device  verify-ios-1  cloning Clerk Verify Template iOS
install ios-3f9a1c2e07b1  on verify-ios-1
device  verify-ios-1  local  leased by this worktree  installed ios-3f9a1c2e07b1
```

The lane is ready when `up` prints its last line, `device <name> local leased by this worktree installed <build key>`. The `backend`, `device ... cloning`, `install`, `wait`, `instances`, `instance`, and `clerk` lines are progress. `up` settles the credential before it builds or leases anything, so a `wait` line for 1Password comes first. The `instance ... up` line names the new application and says how many settings match the standard file. An `up` in a worktree that already holds its application prints `instance <application id>  held, on <settings>` instead. A reused build prints one `build <key> local reused` line. The build always finishes before `up` claims a lane, so a `wait` line for a full pool comes after the `build ... built` line.

`up` is idempotent. It reuses a build whose key matches the current tree (a hash of every tracked and modified file minus docs and specs) and a lease this worktree already holds. Any change to the tree, including reverting an edit, changes the key, so the next `up` or `run` rebuilds and reinstalls. It builds before it claims a lane, because a build needs no device. `run` calls `up` itself, so `up` exists to start the slow part early. To start the slow part early, run `.claude/skills/verify-clerk-ios/bin/control-clerk-ios up --wait 600 &`, then `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run ...`. `run` prints one `wait` line naming the build, waits for the `up` to finish with no time limit, and uses its lease. `--wait` does not apply to that wait; it bounds waiting for a free lane and for another `run` that holds the device. Give the background `up` a `--wait`: on a full pool, an `up` without it builds, then exits 3 with `POOL_FULL`, and the `run` claims its own lane.

`run` prints the same ready line, `device <name> local leased by this worktree installed <build key>`, every time it holds a lease, whether it just leased the lane or reused one, before its `run <id>` line.

Builds are per worktree: they live in that worktree's `.verify/builds/`. Two worktrees at the same commit have the same build key and still each build once.

Before leasing, `up` and `run` release lanes whose claiming process is gone and whose worktree no longer exists, and print `reap    verify-ios-<n>  (owner process and worktree are gone)` for each.

Because `run` goes through the same lease step as `up`, a `run` also cleans up after worktrees that were removed without `down` (their lanes, applications, users, and daemons), exactly as `up` does.

The lane simulator is a clone of `Clerk Verify Template iOS`, which trusts this Mac's proxy CA. The clone is deleted and re-cloned when a lease is lost or released, so the name `verify-ios-<n>` can map to a different UDID from one lease to the next. Read the UDID from `.verify/leases/ios.json`.

On a Mac, never drive `iPhone Air`, the template, a physical device, or a simulator another worktree holds. Four lane simulators can exist on the Mac at once, across all agents. When all four are taken, `up` and `run` fail with `POOL_FULL`. Pass `--wait <seconds>` to either verb to wait for a lane. While waiting, the CLI prints one `wait` line naming the lanes in use, and prints it again only when that set changes.

Each worktree runs its own agent-device daemon from its own `node_modules`, with state under `.verify/agent-device/`. The CLI passes `AGENT_DEVICE_STATE_DIR` to e2e and to every `agent-device` call, and `down` stops the daemon. A daemon shared across worktrees breaks every worktree once the worktree that started it is removed. If you call `agent-device` yourself, set `AGENT_DEVICE_STATE_DIR=.claude/skills/verify-clerk-ios/.verify/agent-device` and use `.claude/skills/verify-clerk-ios/node_modules/.bin/agent-device`. To find this worktree's daemon pid, read the `would stop` line of `.claude/skills/verify-clerk-ios/bin/control-clerk-ios down --dry-run`. Never print `.verify/agent-device/daemon.json`: it holds the daemon's auth token.

Teardown is `.claude/skills/verify-clerk-ios/bin/control-clerk-ios down` (see Cleanup).

## Test instances

Each worktree has one Clerk application of its own. `up` creates it through Clerk's Platform API and puts its development instance on the standard settings, and `down` deletes it. A spec names no instance. A spec file that needs other settings declares them, and `run` changes the application to match before the tests in that file start. Nothing is shared with another worktree, another repo, or CI, so a spec never meets another session's users or a setting someone changed by hand.

- **The standard instance.** `src/core/instances/base.json` defines it, with everything that can coexist switched on. `config` is the whole body of the Platform API request that puts an instance on the standard settings. `environment` lists the leaves of the instance's public `/v1/environment` that a spec cannot run without. `defaults` lists every other leaf as a new application showed it when the file was written. After the CLI configures a new application, it reads that public environment. A difference in `environment` fails with `INSTANCE_MISCONFIGURED` and names the setting. Run `down`, then `up` once more. If it fails again, Clerk changed what a setting does. Say so in your report, and do not edit the file as part of unrelated work, because three repos share it (edit it, run `node src/core/manifest.ts --write`, and copy `src/core` to the others). A difference in `defaults` is drift in something no spec depends on, and only `doctor` reports it.
- **What a spec declares.** A spec file that runs on the standard instance declares nothing. A spec file that needs other settings exports them once, as a plain literal in the file itself:

  ```ts
  import { test, expect, type InstanceSettings } from '../../fixtures.ts';

  export const instanceSettings: InstanceSettings = {
    config: { auth_multi_factor: { required_for_sign_up: true } },
    environment: { 'user_settings.sign_up.mfa.required': true },
  };
  ```

  `config` is a fragment of Clerk's Platform API instance config. `environment` lists the leaves of the instance's public `/v1/environment` that the change moves, each by its full dotted path and with its new value. The declaration applies to every test in the file, so tests that need different settings go in different files.
- **The rules for a declaration.** The CLI reads the declaration from the text of the file and never runs the file. Each rule fails with a fix line that says what to write.
  - A file has one declaration, and the word `instanceSettings` appears nowhere else in it, comments included.
  - The declaration comes right after the imports. The CLI refuses one that follows code with a `/` in it (a division or a regular expression), because it cannot tell where such code ends without running it.
  - The declaration is a plain literal that holds `config` and `environment` and nothing else. A variable, a spread, a call, a computed key, or a `${}` is refused.
  - Every `config` leaf has a standard value under `config` in `base.json`, and at least one declared value differs from its standard value.
  - Every `environment` leaf is listed in `base.json`, under `environment` or `defaults`, and differs from its standard value.
  - Every leaf the change moves is listed. When one is missing, the failure lists the missing leaves with their values, ready to paste into `environment`.
  - Two files that declare the same `config` expect the same value of every leaf that both list.
- **A spec that names an instance.** `run` refuses a spec file that holds the name of a standing instance, an `instance` argument to a `host` call, or `LAUNCH_PRESETS`. It refuses before it builds or leases anything. `doctor` fails its `settings` check for such a file anywhere under `specs/`, and the fixture throws when a `host` call is given an instance. Each prints the same fix line.
- **How `run` applies declarations.** `run` reads the spec files it selected, groups them by declaration, and runs each group in its own e2e invocation. A run with more than one group prints the groups first. These are the `settings` lines of a `run --all --skip form-entry`, with the output between them left out:

  ```console
  settings 3 groups in this run: standard (7 spec files), organization_settings.force_organization_selection=true (1), auth_multi_factor.required_for_sign_up=true (2)
  settings standard  already on app_3KISJ7t5VmAfMzYEtfINEYwGjTc
  settings changing app_3KISJ7t5VmAfMzYEtfINEYwGjTc from standard to organization_settings.force_organization_selection=true, which specs/golden/session-tasks/choose-organization.e2e.ts declares
  settings organization_settings.force_organization_selection=true  on app_3KISJ7t5VmAfMzYEtfINEYwGjTc in 0.4s (Clerk answered in 0.34s, the instance showed it 0.10s later), 212 settings match
  settings changing app_3KISJ7t5VmAfMzYEtfINEYwGjTc from organization_settings.force_organization_selection=true to auth_multi_factor.required_for_sign_up=true, which specs/golden/session-tasks/complete-setup-mfa.e2e.ts declares
  settings auth_multi_factor.required_for_sign_up=true  on app_3KISJ7t5VmAfMzYEtfINEYwGjTc in 0.4s (Clerk answered in 0.27s, the instance showed it 0.09s later), 212 settings match
  ```

  The group whose settings the application is already on runs first. The other groups follow in the order their first spec file comes in the run, and the standard group runs last unless it is first. One config request moves the application from one group to the next. The request is always the whole standard `config` with the declaration laid over it, so the result never depends on what was applied before. A group starts once the public environment shows its settings. After the run, the application stays on the settings of the last group. The CLI records them, so the next `run` starts with that group and changes nothing it does not need to.
- **Timing.** Clerk answers a settings change in about 0.25 s, and the instance's public environment shows it on the next read, about 0.1 s later. The first spec of the group starts within about a second. In 42 measured changes on iOS and Android, the spec that followed each change passed.
- **A declaration that fails.** A declaration that breaks a rule the CLI can check from the file stops `run` before it builds or leases anything. A declaration that Clerk refuses, or whose `environment` does not match what the instance shows after the change, fails its own group. Every spec file in that group gets a failed result in `run.json`, and the run goes on to the next group. The error names the spec file and quotes what Clerk said. Before the CLI blames the spec for a refusal, it sends the standard `config` alone as a dry run, so a problem in `base.json` is reported as one. Any other failure to apply settings stops the run, and the groups that did not run get failed results too. The Platform API cannot set reverification, the development-mode banner, test mode, or PII protection off.
- **The user limit.** A Clerk development instance holds 100 users. `up` and `run` read the user count first and replace an application that holds 60 or more. Users seeded in the replaced application are gone.
- **The credential.** One team key creates, changes, and deletes the application. The CLI looks in this order, and `doctor` names the one it found in its `instances` line.
  1. `CLERK_PLATFORM_API_KEY`, or `CLERK_PLATFORM_API_KEY_FILE` naming a file only you can read (mode 0600). A set variable that does not work is an error.
  2. A request with no key. In a cloud environment that holds the key as an API credential for `api.clerk.com`, the environment adds the key after the request leaves the machine, so no key is ever in the session.
  3. The 1Password CLI. The key's 1Password secret reference has the shape `op://<vault>/<item>/credential`, and this repository does not hold it. The team's private setup note has the real one. The CLI reads the reference from `VERIFY_PLATFORM_KEY_REFERENCE`, or from the one line of `~/.verify/clerk-platform-key-reference`. With neither set it skips 1Password, and the fix line says how to set one. With a reference set it prints `wait    reading the team key from 1Password; approve the request in the 1Password app within 60s`, and the 1Password app asks the person at the Mac to approve. An agent cannot approve it, so tell the person before the first command. A refused or unanswered request is an error. The output names the source as `1Password` and never prints the reference.
- **Which commands need it.** `doctor` checks it every time. `up` uses it when it has to create, repair, or replace the application. `run` uses it for the same reasons and when it has to change settings, so a `run` whose spec files all declare the settings the application is already on does not. `down` uses it when the worktree holds an application. `screen` and `attach` never do. Each command looks it up at most once, so with 1Password each of those commands asks once.
- **When it is missing.** `doctor` prints `FAIL  instances  no Clerk Platform API credential works here (...)` with what it tried and the fix. An `up` that has to create the application and a `run` that has to change settings exit 3 with `KEYS_MISSING` before they build or lease a device. `down` releases the device first and then fails the same way. The ledger keeps the application, and `down` again with the credential deletes it.
- **What the key can reach.** Only the verification workspace, `org_3KHungJxbvIscuSvy8oos5MHAli`, which holds nothing but these applications. The CLI refuses a key of any other workspace. It also refuses to create or delete anything while that workspace holds an application whose name does not start with `verify-throwaway-`. Never print the key or the 1Password reference, and never put either in a file inside a repository.
- **Lifetime.** An application's name carries a deadline, six hours after it was created (`verify-throwaway-until-<utc>-<hex>`; `VERIFY_THROWAWAY_HOURS` sets 2 to 72). `down` deletes this worktree's application at once and confirms it is gone from Clerk's list. If a session dies without `down`, a later command on any machine that creates, changes, or deletes an application also deletes applications whose deadline has passed by Clerk's clock, at most five per command, and prints a `reap` line for each. Nothing is deleted before its own deadline, so no session can remove another's live application. When this worktree's own application is within an hour of its deadline, the next `up` or `run` replaces it first, and users seeded in the old one are gone.
- **Recovery.** Every step can be repeated. The ledger gets the application's name before the create request is sent, and the keys go to a private file under `.verify/instances/` as soon as Clerk answers. The CLI records the settings an application is on only after the public environment shows them. A command that dies during a change leaves no record, and the next `up` or `run` then sends the standard settings again. A rerun also replaces an application whose keys were lost or that Clerk has stopped serving, and `down` deletes whatever the ledger names.
- **One application per worktree.** This repo has one platform, so a worktree holds one application. The shared core creates a second one only when two runs drive at the same time in one worktree on different declarations, which takes a host with two platforms. `down` deletes every application the worktree holds.
- **Which API host.** The Backend API calls that seed users use the instance's own secret key on `api.clerk.com`. A cloud API credential with path prefix `/v1/platform/` is attached to Platform API calls only, so those Backend API calls keep the instance's own key. A cloud API credential with no path prefix replaces that key on every request to the host, and the call gets 401. The CLI then sends the same request to `api.clerk.dev`, the older name of the same API, and stays there for the rest of the command if that succeeds. `up` prints `clerk   Backend API on <host>` and `doctor` prints the same in `clerk-api`. If neither name accepts the key, the command fails with `NOT_READY` and a fix that names the credential's path prefix and the allowed domains.
- **Requests.** `up` sends 4 Platform API requests: who the key belongs to, the list of applications, the create, and the configure. A `run` that changes settings sends 2 and one more for each change, and a `run` that changes nothing sends none. `down` sends 4 and `doctor` sends 2. A session of `up`, `run --all`, and `down` sends 12, and a session that stays on the standard instance sends 8. Each command that reads the key from 1Password sends one more. A command prints its count, as in `clerk   Platform API: 4 requests by this command so far`. Clerk's edge is configured for 100 a minute for the whole workspace, shared by every session. On a 429 the CLI prints a `wait` line, waits as long as Clerk asks, up to a minute, and retries up to six times. If the limit does not lift, the verb fails with `RATE_LIMITED`, which is retryable.
- **The standing instances.** Three long-lived instances from the JavaScript repo's integration set still work, for a machine with no credential: `with-email-codes`, `with-session-tasks`, and `with-session-tasks-setup-mfa`. `CLERK_TEST_KEYS_JSON`, or `VERIFY_INSTANCES=standing` with `.keys.json` in the main checkout, selects them. So does a machine that has `.keys.json`, no key variable, no key-attaching proxy, and no 1Password reference or no 1Password CLI. `VERIFY_INSTANCES=throwaway` refuses that fallback. A worktree that holds a throwaway application keeps using it until `down`. A standing instance cannot be changed, so the CLI checks a declaration there and does not apply it. A spec file with no declaration runs on `with-email-codes`. The forced organization selection declaration runs on `with-session-tasks`, and the required MFA at sign-up declaration runs on `with-session-tasks-setup-mfa`. Any other declaration fails with a fix line that says to run on a throwaway instance. With the standing instances `doctor` prints `keys` and one `instance:<name>` check per instance, with its enabled strategies, in place of `settings`. It reads the keys from `.keys.json` at the root of the main clerk-ios checkout or from `CLERK_TEST_KEYS_JSON`. Other repos and CI share the standing instances, so their users and settings are not yours alone.

## Remote simulator

A Linux machine cannot run an iOS simulator, so there the CLI leases one on a GitHub Actions runner and drives it through a tunnel. Every verb, spec, and evidence file is the same. `up` and `run` print which backend they chose and why in a `backend` line, and `doctor` prints the same as its `backend` check:

```console
backend remote  local is out: the iOS simulator needs macOS and this machine runs linux; the device runs on a CI runner (blacksmith-6vcpu-macos-27 unless --runner names another), started through verify-remote.yml on clerk/clerk-ios
```

`--backend auto` is the default: `local` when this machine can run the simulator, otherwise `remote`. `--backend local` or `--backend remote` forces one, and fails with `UNSUPPORTED` when this machine cannot use it. A worktree that holds a lease keeps that lease's backend until `down`.

The Launch section above describes the Mac lane: the local build, `.verify/builds/`, the lane pool, `--wait`, and the per-worktree agent-device daemon. None of that exists for a remote simulator. The remote loop is commit, push, run:

```console
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios doctor  # on Linux this checks the remote path: push access, GitHub REST, the tunnel host
$ git commit -am "..." && git push  # the session builds a pushed commit, never your working tree
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios up
backend remote  local is out: the iOS simulator needs macOS and this machine runs linux; the device runs on a CI runner (...)
build   ios-e4835f8835d9  github-actions  commit 2e11c5ffe39c  the session builds it
device  remote ios  starting session ios1857e9 on blacksmith-6vcpu-macos-27 (idle stop 15 min, cap 60 min)
device  remote ios  run 37346962333 by dispatch  https://github.com/clerk/clerk-ios/actions/runs/37346962333
device  remote ios  tunnel up, iPhone Air on blacksmith-6vcpu-macos-27
install ios-e4835f8835d9  on iPhone Air on blacksmith-6vcpu-macos-27
wait    build 2e11c5ffe39c building 92s; device ready; agent-device up
build   ios-e4835f8835d9  github-actions  2e11c5ffe39c built in 125s on blacksmith-6vcpu-macos-27
device  iPhone Air on blacksmith-6vcpu-macos-27  remote  leased by this worktree  installed ios-e4835f8835d9
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios run auth-start  # reuses the session
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios down  # ends the runner job; do this as soon as you are done
```

- **Ready takes about three minutes on the default runner.** The runner boots the simulator and builds E2EHost at the same time. Run `up` as soon as you have pushed, then write the spec while it builds. The remote simulator is the runner's own `iPhone Air`; the rule against driving `iPhone Air` is about the one on a Mac.
- **After an edit to the app, commit and push, then `run` again.** `run` sees that the app sources changed, asks the same session to build the new commit, and runs once it is installed. The build is incremental: 6 to 9 seconds measured for one-file edits, longer for a change many files depend on. Uncommitted changes to the app sources, or a HEAD that GitHub does not have, fail with `BUILD_FAILED` and the fix `git commit` or `git push`. Edits to specs, docs, and this skill need no commit and no push: specs run from your working tree, and a session that already holds the build for your app sources is reused as is.
- **A session keeps the verify code of the commit it started on.** The build steps in `src/platform/ios/session-device.ts` are read again from each commit it builds, so a push that changes them takes effect at that build. The session agent in `src/core/` is not: after a push that changes `src/core/`, `up` and `run` fail with `NOT_READY` and the fix `down`, then `up`.
- **A session costs money by the minute.** It stops itself after 15 minutes without a call from the CLI, and always after 60 minutes. `down` stops it at once. After an idle stop, the next `up` or `run` prints `lost ... renewing` and starts a new session. A session with under two minutes left before its cap is replaced the same way, with `ending ... renewing`. Set `VERIFY_REMOTE_IDLE_MINUTES` or `VERIFY_REMOTE_CAP_MINUTES` to change the limits for sessions you start.
- **A crashed run cannot strand a session for long.** Each checkout has a random id in `.verify/remote/owner`, and its sessions carry it. When the checkout holds no lease, `up` and `run` end any session with that id that is still running, and `down --stale` does so at any time. The idle stop ends whatever they miss, such as the session of a checkout that was deleted.
- **The runner label is one setting.** The default is `blacksmith-6vcpu-macos-27` (Xcode 27, iOS 27, `iPhone Air`), which is billed. `--runner xcode-27` or `VERIFY_REMOTE_RUNNER=xcode-27` uses a free GitHub-hosted label instead and needs no other change; there the first build took 12 minutes instead of 2. A held session keeps its label, and `--runner` with another label fails until `down`.
- **The job that reads the request has its own label.** Before the session's runner starts, a job of a few seconds checks the request. For a session on a Blacksmith label it runs on `blacksmith-2vcpu-ubuntu-2404`, so the session does not first wait in the queue for GitHub's own runners. That job is billed as one minute of a 2 vCPU Linux runner per session, about 0.004 USD at the public price. For a session on a GitHub-hosted label it runs on `ubuntu-latest`, which is free, and so do `doctor`'s probe and `doctor --live`. `VERIFY_REMOTE_PLAN_RUNNER=<label>` names another label. While a run has not published its tunnel, `up` and `doctor` print which label it is waiting for and for how long, so a slow start names the queue that is slow. A session started by a pushed `verify-remote/*` branch has its request read on `ubuntu-latest`.
- **`screen`, explored specs, video, screenshots, `app.log`, and `states.jsonl` work the same.** `run.json` also has `remote`, with `provider`, `runner`, and `builtSha`.
- **`attach` needs `gh` with `gh pr comment --attach`.** A machine without it reports `gh-attach` as failing in `doctor`, and can still run and keep evidence. Name the run id in the PR and say the evidence was not attached.
- **What a session needs from the machine:** Node 24 (on an older Node the CLI reruns itself under `node@24` through `npx` and says so), a pushed branch that holds `.github/workflows/verify-remote.yml`, permission to dispatch that workflow or to push a branch named `verify-remote/*`, REST access to the repository, and network access to `*.trycloudflare.com`, `api.clerk.com`, `api.clerk.dev`, and `*.clerk.accounts.dev`. It also needs a credential for test instances, which in a cloud environment is an API credential for `api.clerk.com` with path prefix `/v1/platform/` (see [Test instances](#test-instances)). A machine that uses the standing instances instead passes their keys in `CLERK_TEST_KEYS_JSON`, the same JSON as `.keys.json`, with `pk` and `sk` for each standing instance its specs run on. `doctor --backend remote` checks each of these and prints the fix. `doctor --backend remote --live` also starts a real session on a free runner with no simulator, reaches it through the tunnel, and stops it, in about a minute. Add `--runner <label>` to make that live check boot the simulator on that label.
- **Secrets.** The Platform API key and the instances' secret keys never leave this machine, and in a cloud environment the Platform API key never enters it. The session's bearer token is made here, lives in `.verify/remote/<session>/token`, and is deleted by `down`; never print it. GitHub sees only the token's SHA-256. The runner sees sign-in tickets and publishable keys as launch arguments, uploads no artifact, and prints none of them in its job log. The tunnel ends TLS at Cloudflare, so Cloudflare can read what passes through it, the bearer and tickets included. The tunnel's host name is public for the life of the session, and every route on it answers 403 without the bearer.

A cloud sandbox works without proxy configuration. Node ignores `HTTPS_PROXY` unless told to honor it, so the CLI decides: it goes through the proxy when the direct path to GitHub does not work, meaning it cannot connect or GitHub rejects the machine's token on it, and it reruns itself with the proxy in effect for itself, e2e, and agent-device. A Claude Code cloud sandbox is the second case: its `GH_TOKEN` is a placeholder that only the sandbox proxy turns into a real credential. A machine that reaches GitHub directly stays direct. `doctor` prints the choice and the reason in `remote-env`. A blocked host shows in `doctor` as `blocked: ...`, and the fix is to add the host to the environment's allowed domains.

What a remote session needs from GitHub is split in two. REST starts, reads, and ends sessions, and in a Claude Code cloud session it uses the session user's own access. `git push` gets a commit you make to GitHub so the session can build it, and in a Claude Code cloud session it needs the Claude GitHub App installed on the repository; a 403 on push means it is not. Without push access you can still verify commits GitHub already has, and write and run explored specs against them.

## Doctor

```console
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios doctor --json
```

Run it first, and again whenever anything looks off. It changes nothing on this machine. With the remote backend it starts one short probe run on GitHub, which needs no runner beyond a free job, and with `--live` one short session. With `--live` it also creates one application, configures it, compares it with the standard file, finds the Backend API host, and deletes it, in about two seconds, unless this worktree already holds an application. If this machine may not dispatch the workflow, the probe pushes a `verify-remote/...` branch holding HEAD, which the run deletes; it does that only for a HEAD that is already on GitHub. It checks:

- Which backend it chose and why, then Node 24 and Xcode. With the remote backend it checks git fetch and a dry-run push, that HEAD is not behind or off the branch on the remote (`git-head`, which is what a reused, stale clone looks like; the fix is `git fetch origin <branch> && git reset --hard FETCH_HEAD`), GitHub REST, that GitHub has HEAD, that a session can be triggered and its answer read back (a probe run that uses only a free job), and network access to the tunnel and Clerk hosts, in place of the Xcode, template, and lane checks.
- `e2e-pins`: the installed e2e and `@e2e-dev/mobile` match the pinned versions. `agent-device-global` (local backend only): the global `agent-device` matches the version `@e2e-dev/mobile` depends on.
- The template simulator. `proxy-trust`: when macOS has an HTTPS proxy on, the template must trust its CA. With no system HTTPS proxy, the check passes.
- `instances`: where test instances come from, the credential it found and the workspace that reaches, and the application this worktree holds with the settings it is on. It fails with the fix when no credential works, also when the application is already up, because `down` will need it. `clerk-api`: the Backend API host in use, once an application exists to try it with. `settings`: for each application the worktree holds, the settings it is on, the spec file that asked for them, and how many settings match, then how many spec files declare settings, as in `app_3KISJ7t5VmAfMzYEtfINEYwGjTc is on standard; 212 settings match src/core/instances/base.json; 3 spec files declare settings`. It fails when a held application does not match its record, and when any spec file under `specs/` has a malformed declaration or names an instance. With the standing instances it prints other checks in place of `settings` (see [Test instances](#test-instances)).
- Whether an E2EHost build matches the current tree. With the remote backend, whether the held session has built the current tree.
- `gh pr comment --attach` support, stale device claims, and drift in `src/core/`.
- Whether an agent-device daemon, the Mac-wide one in `~/.agent-device` or this worktree's own, runs from an install that no longer exists. The fix names the pid to kill.
- Whether every feature in the Feature Map has its feature file and at least one golden spec.

A failing check prints the command that fixes it, and `doctor` exits 3. A check that could not run because an earlier one failed still prints, as `not run: needs <check>`. On a Mac with a working credential, before the first `up`, only `build` fails, with fix `.claude/skills/verify-clerk-ios/bin/control-clerk-ios up`. With the remote backend, `build` fails until a session holds the current build, `remote-commit` fails until HEAD is pushed, and `gh-attach` fails on a machine with no `gh`.

## Drive

Input only goes through specs. A spec is a TypeScript file that uses the `host` fixture from `specs/fixtures.ts` and e2e's `screen` locators.

```console
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios run auth-start  # one feature (specs/golden/auth-start/)
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios run sign-up/request-code  # one spec
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios run specs/explored/resend.e2e.ts  # a spec you wrote
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios run --all --skip form-entry  # every golden spec except form entry
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios run sign-up --skip form-entry  # one feature without its form-entry spec
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios run auth-start sign-up organizations  # several targets in one run, one lease, one video
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios screen  # current UI tree with testIds and VerifyState
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios screen --png  # plus a screenshot in scratch
```

`run` flags are `--skip form-entry`, `--include known-bug`, `--grep <regex>`, `--no-video`, `--backend auto|local|remote`, `--runner <label>` (remote only), and `--wait <seconds>` (how long to wait for a free lane or for another verb in this worktree that holds the device).

The `host` fixture:

```ts
import { test, expect, CLERK_TEST_CODE } from '../../fixtures.ts';

test('profile shows the seeded user', async ({ host, screen }) => {
  const user = await host.seedUser();                                         // BAPI user, ledgered for cleanup
  const state = await host.launch({ signedInAs: user, screen: 'userProfile' }); // ticket sign-in, fresh storage
  expect(state.userId).toBe(user.id);
  await expect(screen.getByText(user.email)).toBeVisible();
  await host.screenshot('profile');                                           // runs/<id>/screenshots/profile.png
});
```

- `host.launch({ signedInAs?, screen?, authMode?, debugLogs?, keepStorage? })` relaunches E2EHost with launch arguments and returns the first `VerifyState` for that launch that is ready. It takes no instance. The app runs against the worktree's application, on the settings the spec file declares. Every launch starts with fresh storage, so a launch with no `signedInAs` is signed out, on `home` or any other screen. Screens are `home`, `auth`, `userProfile`, `orgSwitcher`, `orgList`, and `orgProfile`. Auth modes are `signIn`, `signUp`, and `signInOrUp`.
- `host.seedUser({ phone? })` creates a `+clerk_test` user in that application. `host.newEmail()` reserves an email for a form sign-up.
- `host.state()` reads the footer. `host.waitForState(predicate, timeoutMs?)` polls it. The footer is not readable while a sheet covers the host.
- `host.tap(locator)` taps the middle of the node's box, and `host.fill(locator, text)` taps it and types `text` into the focused field. Use them for every action inside AuthView, UserProfileView, and organization sheets. On iOS 27 a SwiftUI toolbar adds a hittable full-screen `Toolbar` node, and agent-device 0.21.18 refuses `locator.tap()` and `locator.fill()` under it with "covered by another visible element". Plain locator actions still work on the E2EHost home screen.
- The footer `verify.state` holds `verify ` plus one line of JSON: `screen`, `environmentLoaded`, `signedIn`, `userId`, `sessionId`, `sessionStatus`, `pendingTasks`, `orgId`, `signInStatus`, `signUpStatus`, `ticket`, `lastError`, `runId`, and `launchId`. `screen` is what is on screen, not what was asked for. `signedIn` is true for a pending session, so read `sessionStatus`. The footer shows in screenshots and videos. Its ids, `sessionId` included, are not secrets: a session id cannot sign anyone in. Sealing still searches every evidence file for the real secrets a run used (secret keys and tickets) and blocks `attach` on a hit.
- Locate with SDK identifiers, `screen.getByTestId('clerk.auth.start.identifier')`. The full list is in `Sources/ClerkKitUI/Components/Auth/ClerkAccessibilityIdentifiers.swift`. E2EHost adds `e2e.auth.signIn`, `verify.signOut`, `verify.userId`, and `verify.state`.

There are two ways to check work.

1. **Golden specs** under `specs/golden/<feature>/` are committed, cover the Feature Map in `features/`, and run unchanged as regression. Run the features your change touches.
2. **New work.** Write a spec under `specs/explored/` (gitignored), run it, and read the end state with `.claude/skills/verify-clerk-ios/bin/control-clerk-ios screen`. Call `screen` after any run, passing or failing, whenever you need the next locator: after a pass it shows the screen the spec ended on, which is where the next step of new work starts. `screen` works right after `up` too, but the app then runs without launch arguments, so it shows the `error` screen (no publishable key). To look at a real screen, run a spec that launches it first, even one that only calls `host.launch`. `screen.getByTestId` matches any accessibility identifier, the SDK's `clerk.*` ids and E2EHost's own plain strings such as `e2e.auth.signIn` or an id you add for a probe. Fix locators from the `screen` output until it passes. To explore a setting the standard instance does not have, export `instanceSettings` from the explored spec, as [Test instances](#test-instances) describes. Take the leaf names from `environment` and `defaults` in `src/core/instances/base.json`, and when the change moves a leaf you did not list, paste the leaves the failure prints. The declaration is part of the spec file, so it goes with the spec when the PR commits it into `specs/golden/<feature>/`. The PR commits that spec into `specs/golden/<feature>/` and updates the feature file when the change adds or changes a user-facing behavior. Otherwise the spec stays with the run evidence (`runs/<id>/specs/` keeps a copy of every spec a run used).

An explored spec sits one level below `specs/`, so it imports the fixture as `../fixtures.ts`, where a golden spec uses `../../fixtures.ts`:

```ts
import { test, expect } from '../fixtures.ts';
```

A failing spec prints `FAIL`, the first assertion message, and the path of its failure page, and `run` exits 1. The failure page (`runs/<id>/e2e/failures/*.md`) lists every step, the screen tree at the failure, and a screenshot. In a run with several groups it is under the e2e directory of the group the spec ran in, such as `runs/<id>/e2e-2/failures/`, and `run` prints the path. `next` points at it.

```console
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios run specs/explored/resend-countdown.e2e.ts
  FAIL  explored/resend-countdown.e2e.ts  shows the resend countdown  14.1s
        expect.toBeVisible failed; locator: getByTestId("clerk.auth.code.resend"); expected: visible; observed: no node (match count 0)
        failure page  .verify/runs/r20261003-020926-ba6f/e2e/failures/specs_explored_resend-countdown.e2e.ts-....md
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios screen
button  "Resend (29)"   id=clerk.auth.code.resend   screen.getByTestId('clerk.auth.code.resend')
$ git mv specs/explored/resend-countdown.e2e.ts specs/golden/sign-up/
```

Every spec keeps at least one exact assertion on `verify.state` or an SDK identifier.

A tap or fill on a node that is not on screen fails with `LOCATOR_NOT_FOUND`. Assert `await expect(locator).toBeVisible()` first when you are unsure the node is there, because its failure reads `observed: no node (match count 0)`, which says plainly that the element is missing.

### AI judge (off by default)

e2e's `agent.assert` can judge visual claims that selectors cannot check. It is off. Golden specs never use it. To trial it in an explored spec, install `ai` (`npm i -D ai`), log in with `npx e2e login openai` (a ChatGPT Plus or Pro plan), and set `VERIFY_JUDGE_MODEL=chatgpt:<model-id>` (ids from `npx e2e models`). Only then does the composed config set `agents.default.model`. Without the variable the config has no model and any agent step fails.

## Test users and sign-in

Clerk's test mode makes all of this safe to type into the real app.

- **Emails.** Any address that contains `+clerk_test@` is a test address. Clerk sends no mail and accepts the code below. The fixture mints `verify_<runId>_<n>+clerk_test@example.com`, new per run, so sign-up never collides.
- **Phones.** Any US number from 555-0100 to 555-0199 is a test number. Type it as ten digits, for example `5555550142`. On the standing instances the numbers are shared across repos, CI, and agents, so always get one from `host.seedUser({ phone: true })` instead of picking one by hand.
- **One-time code.** `424242` verifies every email code and SMS code for test addresses and phones. Specs use the constant `CLERK_TEST_CODE`. It is public, so it is not an e2e secret, and screenshots after the fill are kept.
- **Passwords.** The standard instance requires a password at sign-up. Use a throwaway per run, such as `Verify-<runId>-Pw1!`.
- **Authenticator (TOTP) codes.** Read the setup key from `clerk.auth.sessionTask.totp.secret`, then compute the 6-digit code with RFC 6238 (SHA-1, 30 second step). `specs/golden/session-tasks/complete-setup-mfa.e2e.ts` has a helper.

The standard instance covers most specs. A spec file that needs something else declares it, as [Test instances](#test-instances) describes.

| A spec needs | Its file declares |
| --- | --- |
| Any auth method or signed-in feature: email code, email link, phone code, password, username, TOTP, backup codes, organizations, social buttons | Nothing. The standard instance has all of them. |
| Sign-ins that stop on the "set up MFA" session task | `config: { auth_multi_factor: { required_for_sign_up: true } }` and `environment: { 'user_settings.sign_up.mfa.required': true }`, as in `specs/golden/session-tasks/setup-mfa.e2e.ts` |
| Sign-ins that stop on the "choose or create an organization" session task | `config: { organization_settings: { force_organization_selection: true } }` and `environment: { 'organization_settings.force_organization_selection': true }`, as in `specs/golden/session-tasks/choose-organization.e2e.ts` |

| Step | Identifier |
| --- | --- |
| Identifier field (email or username) | `clerk.auth.start.identifier` |
| Switch between email and phone | `clerk.auth.start.identifierSwitcher` |
| Phone field | `clerk.auth.start.phoneNumber` |
| Continue on the start screen | `clerk.auth.start.continue` |
| Sign-in code field | `clerk.auth.signIn.code` |
| Sign-in password field | `clerk.auth.signIn.password` |
| Try another method on a code or password screen | `clerk.auth.signIn.useAnotherMethod` |
| Try another method on the email link screen (no identifier there) | `screen.getByRole('button', { name: 'Use another method' })` |
| Pick a method from the list | `clerk.auth.signIn.alternativeMethod.<strategy>`, for example `clerk.auth.signIn.alternativeMethod.email_code` |
| Sign-up email, password, continue | `clerk.auth.signUp.emailAddress`, `clerk.auth.signUp.password`, `clerk.auth.signUp.continue` |
| Sign-up code field | `clerk.auth.signUp.code` |
| Legal consent, when shown | `clerk.auth.signUp.legalAccepted` |
| MFA setup choices | `clerk.auth.sessionTask.setupMfa.smsCode`, `clerk.auth.sessionTask.setupMfa.authenticatorApp` |

Prove the result from the host's state, not from the screen alone:

```ts
import { test, expect, CLERK_TEST_CODE } from '../../fixtures.ts';

test('signs in with the email code', { tags: ['form-entry'] }, async ({ host, screen }) => {
  const user = await host.seedUser();
  await host.launch({ screen: 'auth', authMode: 'signIn' });
  await host.fill(screen.getByTestId('clerk.auth.start.identifier'), user.email);
  await host.tap(screen.getByTestId('clerk.auth.start.continue'));
  await host.tap(screen.getByRole('button', { name: 'Use another method' }));
  await host.tap(screen.getByTestId('clerk.auth.signIn.alternativeMethod.email_code'));
  await host.fill(screen.getByTestId('clerk.auth.signIn.code'), CLERK_TEST_CODE);
  const state = await host.waitForState((s) => s.signedIn);
  expect(state.userId).toBe(user.id);
  await host.screenshot('signed-in');
});
```

On the standard instance an email sign-in starts on the email-link screen, so the spec switches to the email code through `Use another method`. For a phone sign-in, tap `clerk.auth.start.identifierSwitcher`, fill `clerk.auth.start.phoneNumber` with the seeded user's phone, continue, and type the same code. For sign-up, launch with `authMode: 'signUp'`, fill the email from `host.newEmail()` into `clerk.auth.start.identifier`, continue, type the code into `clerk.auth.signUp.code`, then the run password.

Rules:

- Type only `+clerk_test` emails, 555-0100 to 0199 phones, and `424242`. Never a real person's address, number, or password. The repo is public, and every video lands on a PR.
- Use ticket sign-in (`host.launch({ signedInAs })`) only to reach signed-in screens for features that are not about authentication. A change to an auth method gets a spec that drives the real form.
- Tag every spec that types a code `form-entry`. Those specs run by default. An agent runtime that refuses to type codes into an app that talks to hosted Clerk runs `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run --skip form-entry`, which reports them as `skipped by --skip form-entry`, and says so in the PR. CI runs the skipped specs.
- Tag a golden spec that reproduces an open SDK bug `known-bug`, with a title that names the bug. e2e has no expected-failure status, so `run` leaves `known-bug` specs out unless you pass `--include known-bug`, and reports them as `skipped: known-bug`. A tag on both wins over `form-entry`. A feature whose only golden spec is `known-bug` still passes the Feature Map check. Remove the tag in the PR that fixes the bug.
- The form-entry specs, one command each: `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run sign-in-email-code/complete`, `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run sign-up/complete`, and `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run session-tasks/complete-setup-mfa`.
- `.claude/skills/verify-clerk-ios/bin/control-clerk-ios down` deletes every user the run created, including users created through the sign-up form. With a throwaway application it deletes the whole application they live in. On the standing instances it deletes each user by test email.

## Evidence

Every `run` writes `.claude/skills/verify-clerk-ios/.verify/runs/<run-id>/` and prints its path:

| File | What it is |
| --- | --- |
| `run.json` | The sealed record: `results` per spec, `gitHead`, `dirty`, `build` (the build key), `backend`, `device`, `identities`, `instances` (each instance the run used, as `application` with the application id or `standing` with the name of a standing instance), `settings`, and `tainted` files. `settings` has one entry per group, in the order the groups ran: `label`, `askedBy` (the spec file that declared the settings, or `null` for the standard ones), `specs`, `application`, `changed` (a config request was sent for the group), `held` (the instance still showed the settings when the group ended), and `e2eReport`. For a remote run also `remote`: `provider`, `runner` (the runner label), and `builtSha` (the commit the session built) |
| `video.mp4` | `simctl io recordVideo` of the whole run, recorded on the machine that runs the simulator |
| `screenshots/<label>.png` | Every `host.screenshot(label)` |
| `states.jsonl` | Every `VerifyState` the fixture read, in order, across every test in the run |
| `state.json` | Only the last state of the whole run. With several tests, read per-test states from `states.jsonl` by `launchId`. The run summary's `last state` line shows the same single state |
| `app.log` | `com.clerk.verify` and `com.clerk.sdk` log lines from the run (network lines only with `debugLogs: true`) |
| `e2e/` | e2e's `report.json`, failure pages, and `screen.txt` for failed steps. A run with several groups has one such directory per group, in the order they ran: `e2e/`, `e2e-2/`, `e2e-3/` |
| `e2e.log` | e2e's console output |
| `specs/` | A copy of every spec the run used |

Proof standards: drive the real user path, capture the action and the resulting state (the video plus `states.jsonl`), and check side effects in `states.jsonl` (`userId`, `orgId`, `pendingTasks`), not only the final screen.

After a run, sealing searches the run directory for every secret the run used (the Platform API key, secret keys, tickets). A hit marks the file tainted in `run.json`, and a tainted run cannot be attached.

```console
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios attach <run-id> --pr <n>  # video and every screenshot
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios attach <run-id> --pr <n> --screenshot profile  # video and one screenshot
```

`attach` posts once per run with `gh pr comment --attach`. It refuses a run that is tainted, failed, or shows a user id the run did not create.

Attach the focused run, not the regression run. Run your new or changed spec on its own (`.claude/skills/verify-clerk-ios/bin/control-clerk-ios run specs/explored/<name>.e2e.ts`, or `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run <feature>/<spec>` once it is golden) and attach that run, so the PR video shows only the behavior the change is about. Run the golden specs for every feature you touched in a separate `run`, cite its run id in the PR as regression evidence, and leave its video in `.verify/runs/`.

## Cleanup

```console
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios down --dry-run  # what it would release, stop, and delete: this worktree's application, and on the standing instances each user (instance, id, test email) and organization (instance, id, name)
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios down  # release the simulator (for a remote one, end the runner job), delete this worktree's application with every user in it, stop recorders and this worktree's agent-device daemon
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios down --stale  # also finish cleanup left by a crashed run in this worktree, including a remote session it left running
```

`down` deletes only what this worktree created: its lane simulator, every application in its ledger, and on the standing instances the users in its ledger. It needs the same credential `up` used, releases the simulator first, and if Clerk refuses a delete it fails with the fix `down` again, which finishes what is left. Ledgers live at `~/.verify/ledgers/<id>.jsonl`, where `<id>` is a hash of the worktree path, and `<id>.owner` beside it holds the path. Find yours with `grep -l "$(git rev-parse --show-toplevel)" ~/.verify/ledgers/*.owner`. It never deletes `.verify/runs/`. Evidence survives teardown at `.claude/skills/verify-clerk-ios/.verify/runs/<run-id>/`, and `down` lists the kept runs. Run `down` after a failed iteration too, so no simulator is stranded.

Evidence lives inside the worktree. `git worktree remove` deletes `.verify/runs/` with the rest of the worktree, so copy the runs you need out first.

If a worktree is removed without `down`, the next `up` or `run` in any worktree on the same machine finishes for it. A remote session it left running is the exception: only that session's own idle stop ends it. It deletes that worktree's lane simulator, its applications, and the users in its ledger, stops its agent-device daemon, and prints `reap ledger of <path> ... deleted N users, M organizations, K applications, stopped agent-device <pid>`. Then it marks every open ledger entry done. The ledger files stay on disk.

A ledger can number a test email that never became a user: a sign-up spec that stops at the code screen reserves `verify_<run>_<n>` but creates nothing. `down` finds no user for it and deletes 0, which is correct.

`down --dry-run --json` and `down --json` print different shapes. A dry run prints `{ dryRun: true, wouldRelease, wouldDelete, wouldStop, keptRuns }`, where `wouldDelete` lists `{ kind: 'application', name }`, `{ kind: 'user', instance, id, email }`, and `{ kind: 'organization', instance, id, name }` entries. A real `down` prints `{ dryRun: false, released, deletedUsers, deletedOrganizations, deletedApplications, stoppedProcesses, keptRuns }`, where `deletedApplications` lists `{ name }`. `up --json` also has `instances`, one `{ source: 'throwaway', id, name, created, settings }` per application the worktree holds, or one `{ source: 'standing', instance }` on the standing instances. Lane slots are machine-wide claims under `~/.verify/claims/`. A slot changes hands only by compare-and-swap, so two worktrees never hold the same lane.

## Helpers

- `.claude/skills/verify-clerk-ios/bin/control-clerk-ios` is the only helper. It is executable. Every invocation is shown above.
- `e2e.config.ts` composes the e2e config from the CLI's run context. `npx e2e list` works from `.claude/skills/verify-clerk-ios/` while a lease is held.
- `specs/fixtures.ts` is the `host` fixture. It takes its screen names from `src/host.ts`, so it is the same file in every repo.
- `src/core/instances/` creates, configures, and deletes the worktree's application. `base.json` is the standard settings. `settings.ts` reads a spec file's declaration, checks it, and groups spec files. `platform.ts` is the Platform API client and the one place that names the workspace. `throwaway.ts` is the application's lifecycle, and `instances.ts` chooses between a throwaway application and the standing instances.
- `src/core/remote/` is the remote backend: the session agent that runs on the runner, the GitHub Actions provider, and the tunnel settings (`tunnel.ts` is the one place that names the tunnel host). `.github/workflows/verify-remote.yml` is the session workflow.
- `npm test --prefix .claude/skills/verify-clerk-ios` runs the CLI's unit tests (`node --test test/*.test.ts`), with no network, keys, or simulator. `testing/` holds helper processes those tests spawn; they are not tests themselves. `npm run typecheck` runs `tsc`.
- `features/` is the Feature Map. Start with `features/README.md`.

Keep the map honest with `/maintain-verification-skill`.
