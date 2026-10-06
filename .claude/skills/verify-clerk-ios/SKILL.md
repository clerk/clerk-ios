---
name: verify-clerk-ios
description: Drive the clerk-ios SDK UI (AuthView, UserButton, UserProfileView, OrganizationSwitcher, session tasks) in the E2EHost app on an iOS simulator against a real Clerk development instance that the session creates and deletes, and capture video, screenshots, and host state as evidence. Use it to prove any change to ClerkKit, ClerkKitUI, or E2EHost works before calling it done, to reproduce a UI bug, or to run the golden regression specs.
---

# verify-clerk-ios

`.claude/skills/verify-clerk-ios/bin/control-clerk-ios` is a control CLI over [e2e](https://github.com/tester-army/e2e) 0.18.0 and `@e2e-dev/mobile` 0.10.0. It builds E2EHost, leases a simulator, creates one Clerk application for the worktree, seeds `+clerk_test` users, runs specs, and keeps the evidence. It needs a Mac with Xcode.

No change to clerk-ios UI or auth behavior is done until a `run` on the real host shows the changed behavior.

Run every command from the repo root. In the prose below, `doctor`, `up`, `run`, `screen`, `attach`, and `down` are verbs of that CLI. Paths that begin `specs/`, `features/`, `references/`, `src/`, or `.verify/` are inside `.claude/skills/verify-clerk-ios/`. Every error prints a `fix` line. Every verb takes `--json`, and [CLI output](references/output.md) has its shape and the exit codes.

## Launch

Set up each machine once.

1. Install Node 24, at 24.8.0 or newer, and Xcode with an iOS simulator runtime.
2. Create the template simulator, which the CLI clones to make each simulator it drives, for example with `xcrun simctl clone "iPhone Air" "Clerk Verify Template iOS"`. If this Mac sends HTTPS through a debugging proxy, boot the template once, install and trust the proxy's CA in it, and shut it down.
3. Give the machine the team's Clerk Platform API key. Set `CLERK_PLATFORM_API_KEY`, or set `CLERK_PLATFORM_API_KEY_FILE` to a file that only you can read (mode 0600). To keep the key in 1Password instead, install the 1Password CLI, turn on its desktop app integration, and put the key's secret reference in `VERIFY_PLATFORM_KEY_REFERENCE` or as the one line of `~/.verify/clerk-platform-key-reference`. The reference has the shape `op://<vault>/<item>/credential`, and the team's private setup note has the real one. Never put the key or the reference in a file inside a repository.

Then, in each worktree:

```console
$ npm ci --prefix .claude/skills/verify-clerk-ios                 # once per worktree
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios doctor
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios up
device  verify-ios-<n>  local  leased by this worktree  installed <build key>
```

`up` builds E2EHost for the current tree, creates this worktree's Clerk application, clones the template into a lane simulator named `verify-ios-<n>`, and installs the build. It prints a line for each step. The lane is ready when `up` prints the `device` line above, which is its last line. `run` does the same steps itself and prints the same line, so `up` only starts the slow part early. Teardown is `down` (see [Cleanup](#cleanup)).

With the key in 1Password, a command that needs it prints `wait    reading the team key from 1Password; approve the request in the 1Password app within 60s`, and the 1Password app asks the person at the Mac to approve. An agent cannot approve the request, so tell the person before the first command.

`up` is idempotent. It keeps a lease this worktree already holds, and it reuses a build whose key matches the current tree. The key is a hash of the tracked and untracked files under `Sources`, `Examples/E2EHost`, `Package.swift`, and `Clerk.xcworkspace`, minus Markdown. A change to any of those files changes the key, so the next `up` or `run` builds that key, unless this worktree already built it, and reinstalls.

The Clerk application is this worktree's own. `up` creates it through Clerk's Platform API, in the team's verification workspace, and puts its development instance on the standard settings in `src/core/instances/base.json`. It holds only the users that this worktree's runs create, and `down` deletes it. A spec file that needs other settings declares them (see [Drive](#drive)). [Test instances](references/instances.md) has the credential lookup, the application's lifetime, and its limits.

The CLI drives only `verify-ios-<n>`. Never drive any other simulator, the template, a physical device, or a lane another worktree holds. A Mac has four lanes, shared by every worktree on it. When all four are taken, `up` and `run` fail with `POOL_FULL`, and `--wait <seconds>` on either verb waits for a lane. The CLI deletes a lane and clones it again when its lease is lost or released, so read the simulator's UDID from `deviceId` in `.verify/leases/ios.json` and not from an earlier run.

## Doctor

```console
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios doctor
```

Run it first, and again whenever anything looks off. Without `--live` it only reads. It creates no file, no simulator, and no Clerk application. Each line starts with `ok`, `warn`, `skip`, or `FAIL`, then has the id of the check and what the check found. `skip` marks a check that did not run, and its text starts with `not run:`. A failing check also prints a `fix:` line with the command to run, and `doctor` exits 3. A warning does not change the exit code.

| Checks | Pass when |
| --- | --- |
| `node`, `xcode`, `e2e-pins` | Node is 24.8.0 or newer on 24, `xcodebuild` runs, and the installed `e2e`, `@e2e-dev/mobile`, and `@e2e-dev/github` are the versions that `package.json` pins |
| `template`, `proxy-trust`, `lane-ports` | `Clerk Verify Template iOS` exists and is shut down. It trusts a custom CA if macOS has a system HTTPS proxy. Every booted `verify-ios-<n>` simulator has a live claim |
| `instances`, `clerk-api`, `settings` | A Platform API credential reaches the verification workspace. Clerk's Backend API accepts the secret key of the application this worktree holds. That application shows the settings recorded for it, and every declaration under `specs/` is well formed |
| `build` | An E2EHost build matches the current tree |
| `gh-attach` | `gh pr comment` has `--attach`. A `gh` without it prints `warn` and not `FAIL`, because only `attach` needs it |
| `stale-claims`, `agent-device-daemon` | No lane is claimed by a worktree that no longer exists, and no agent-device daemon runs from an install that was deleted |
| `feature-map`, `core-drift` | Every feature in `src/host.ts` has a feature file and a golden spec, and `src/core/` matches `src/core/MANIFEST` |

After the once-per-machine setup and before the first `up`, `build` is the one failing check, and its fix is `up`. A machine with no Platform API credential fails `instances`, and the fix line says how to supply one. `doctor --live` also proves that the credential can do the work. It creates one application, configures it, compares it with the standard file, and deletes it, and reports that in a `live-instance` line. When this worktree already holds an application, `doctor --live` creates nothing, and the `live-instance` line is a `skip`.

## Drive

Input reaches the app only through specs. A spec is a TypeScript file that uses the `host` fixture from `specs/fixtures.ts` and e2e's `screen` locators.

```console
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios run auth-start                        # one feature: every spec in specs/golden/auth-start/
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios run sign-up/request-code              # one golden spec
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios run specs/explored/<name>.e2e.ts      # a spec you wrote
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios run auth-start sign-up organizations  # several targets in one run, with one video
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios run --all --skip form-entry           # every golden spec except the ones that type a code
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios screen                                # the UI tree that is on screen now; --png adds a screenshot
```

`run` also takes `--grep <regex>`, `--retries <n>`, `--no-video`, and `--wait <seconds>`. `--retries <n>` runs a failed test again, up to `n` more times. The default is 0, so a run of your own change shows exactly what happened. The wait covers a free lane and another `run` in this worktree that holds the device. A golden spec tagged `known-bug` reproduces an open SDK bug, and `run` leaves it out unless you pass `--include known-bug`.

`--github-report` is for a CI job, not for your own runs. After the run is sealed, `run` hands the results of every settings group to `@e2e-dev/github` as one report. The reporter writes that report to the job summary. When the event of the job names a pull request and the step has a `GITHUB_TOKEN` that may write pull request comments, it also posts one comment and updates that same comment on later runs. When the event names no pull request, as when a status event started PR CI, `--github-pr <n>` names it, and the comment links each test to its source at the commit under test. `run` prints one `github` line that says what the reporter did, the reporter never changes the exit code, and nothing is reported for a run with a tainted file. Without the flag, `run` reports nothing to GitHub.

### Sign in with the form or with a ticket

A change that touches sign-in or sign-up gets a spec that drives the real form with a `+clerk_test` identity and the test code. Any other change reaches a signed-in state with a sign-in ticket, `host.launch({ signedInAs: user })`, which is the intended shortcut and not a fallback. A runtime that cannot type codes into the app skips the typing specs with `--skip form-entry` on `run` and says so in the PR.

Tag every spec that types a code `form-entry`. `run` reports a skipped one as `skipped by --skip form-entry`. Never report it as verified through a ticket launch.

Type only test identities: `+clerk_test` emails, phone numbers 555-0100 to 555-0199, and the code `424242`, which specs import as `CLERK_TEST_CODE`. Never type a real person's address, number, or password. The repository is public, and a run's video can land on a PR. [The feature map index](features/README.md) lists the test identities and the identifier for each step of the forms.

### Write a spec

```ts
import { test, expect } from '../../fixtures.ts';

test('UserProfileView shows the seeded user', async ({ host, screen }) => {
  const user = await host.seedUser();
  const state = await host.launch({ signedInAs: user, screen: 'userProfile' });
  expect(state.userId).toBe(user.id);
  expect(state.sessionStatus).toBe('active');
  await host.tap(screen.getByTestId('clerk.userProfile.row.manageAccount'));
  await expect(screen.getByText(user.email)).toBeVisible({ timeout: 20_000 });
  await host.screenshot('profile');
});
```

- `host.seedUser({ phone? })` creates a `+clerk_test` user in the worktree's application. `host.newEmail()` reserves an address for a sign-up through the form.
- `host.launch({ signedInAs?, screen?, authMode?, debugLogs?, keepStorage? })` relaunches E2EHost and returns the first ready `VerifyState` of that launch. Screens are `home`, `auth`, `userProfile`, `orgSwitcher`, `orgList`, and `orgProfile`. Auth modes are `signIn`, `signUp`, and `signInOrUp`. A launch starts with fresh storage unless `keepStorage` is true, so a launch with no `signedInAs` is signed out.
- `host.state()` reads the state footer, and `host.waitForState(predicate, timeoutMs?)` polls it. The footer cannot be read while a sheet covers the host.
- `host.tap(locator)` is `locator.tap()` with the assertion timeout, and `host.fill(locator, text)` taps a field and types into it. Fill every SDK text field with `host.fill`. An SDK text field shows no text input until it has focus, so a plain `locator.fill()` on an email or name field fails with "no text input found at the provided coordinates to clear".
- `host.screenshot(label)` writes `screenshots/<label>.png` in the run directory.

E2EHost shows its state in a footer with the identifier `verify.state`. The footer holds the word `verify` and one line of JSON: `v`, `screen`, `environmentLoaded`, `signedIn`, `userId`, `sessionId`, `sessionStatus`, `pendingTasks`, `orgId`, `signInStatus`, `signUpStatus`, `ticket`, `lastError`, `runId`, and `launchId`. `v` is the version of the state contract. `screen` is what is on screen, not what the launch asked for. `signedIn` is true for a pending session, so read `sessionStatus`.

Locate nodes with `screen.getByTestId(...)`. The SDK's identifiers start with `clerk.`, and `Sources/ClerkKitUI/Components/Auth/ClerkAccessibilityIdentifiers.swift` lists them. E2EHost adds `e2e.auth.signIn`, `verify.signOut`, `verify.userId`, and `verify.state`. All of these identifiers are internal test hooks, not public API, and they can change. Every spec keeps at least one exact assertion on `verify.state` or on an identifier.

A spec file that needs other settings than the standard ones exports them once, right after its imports, as a plain literal. `run` puts the application on those settings before the tests in that file start. [Test instances](references/instances.md) has the rules for a declaration and what `run` does with several of them.

```ts
export const instanceSettings: InstanceSettings = {
  config: { auth_multi_factor: { required_for_sign_up: true } },
  environment: { 'user_settings.sign_up.mfa.required': true },
};
```

### Check your work

Golden specs under `specs/golden/<feature>/` are committed and cover the feature map in `features/`. Run the features your change touches. For new work:

1. Write a spec under `specs/explored/`, which is gitignored. It imports the fixture as `'../fixtures.ts'`.
2. Run it by path.
3. Run `screen` after the run, pass or fail. It prints the tree the app is on now, one line per node with its role, label, `id=<identifier>`, and a ready `screen.getByTestId('<identifier>')` when the identifier is unique. A `state` line follows.
4. Fix the locators from that output until the spec passes.
5. When the change adds or changes user-facing behavior, move the spec to `specs/golden/<feature>/`, change its import to `'../../fixtures.ts'`, `git add` it, and update the feature file. Otherwise leave it where it is. The run directory keeps a copy of every spec the run used.

A failing spec prints `FAIL`, the first assertion message, and the path of its failure page, and `run` exits 1. The failure page (`.verify/runs/<run-id>/e2e/failures/*.md`) lists every step, the screen tree at the failure, and a screenshot. The `next` line of the run points at it.

With `--retries`, a test that fails and then passes prints `flaky` and the error of its failed attempt, and a `flaky` line under the results counts such tests. `run.json` records the test as `flaky` with its `attempts`, never as passed, and `run` exits 0. The failure page of the failed attempt and the files of every attempt stay in the run directory. A test that fails on every attempt prints `FAIL`, and `run` exits 1.

Right after `up` the app has no launch arguments, so `screen` shows the host's `error` screen. To look at a real screen, first run a spec that launches it. When a node may be missing, assert `await expect(locator).toBeVisible()` before you tap it. That failure reads `observed: no node (match count 0)`, and a failed tap says only `LOCATOR_NOT_FOUND`.

## Evidence

Every `run` writes `.verify/runs/<run-id>/` and prints its path.

| File | What it holds |
| --- | --- |
| `run.json` | The sealed record: `results` per spec, `gitHead`, `dirty`, `build`, `device`, `identities`, `instances`, `settings`, and `tainted` |
| `video.mp4` | `simctl io recordVideo` of the whole run |
| `screenshots/<label>.png` | Every `host.screenshot(label)` |
| `states.jsonl` | Every `VerifyState` the fixture read, in order, across every test in the run. A read that returns the same text as the read before it adds no line |
| `state.json` | The last state of the run only. Read the states of one test from `states.jsonl` by `launchId` |
| `app.log` | The `com.clerk.verify` and `com.clerk.sdk` log lines of the run. The SDK logs errors only, unless the launch passes `debugLogs: true` |
| `e2e/`, `e2e.log` | e2e's `report.json`, its failure pages, and its console output. A run with several settings groups also has `e2e-2/`, `e2e-3/`, and so on |
| `specs/` | A copy of every spec the run used |

A proof drives the real user path. It captures the action and the resulting state, which the video and `states.jsonl` give you. It checks side effects in `states.jsonl` (`userId`, `orgId`, `pendingTasks`), not only the final screen.

After a run, the CLI searches the run directory for every secret the run used: the Platform API key, the instance's secret key, sign-in tickets, and a GitHub token in `GITHUB_TOKEN` or `GH_TOKEN`. A hit marks the file as tainted in `run.json`. The ids in the footer are not secrets, because a session id cannot sign anyone in.

```console
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios attach <run-id> --pr <n>                       # the video and every screenshot
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios attach <run-id> --pr <n> --screenshot profile  # the video and one screenshot
```

`attach` posts one comment per run and PR with `gh pr comment --attach`. It needs a `gh` whose `gh pr comment` has that flag, and it fails with a fix when the flag is missing. It refuses a run that is tainted, that has a failing spec or no passing one, or that shows a user id the run did not create.

Attach the focused run, not the regression run. Run your new or changed spec on its own and attach that run, so the PR video shows only the behavior the change is about. Run the golden specs for every feature you touched in a separate `run`, cite its run id in the PR as regression evidence, and leave its video in `.verify/runs/`.

## Cleanup

```console
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios down --dry-run  # what it would release, delete, and stop
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios down            # release the simulator, delete this worktree's application, stop its processes
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios down --stale    # also release a lane that a crashed run here, or a deleted worktree, left claimed
```

`down` removes only what this worktree created: its lane simulator, its Clerk application with every user and organization in it, the video recorder, and its agent-device daemon. It releases the simulator before it deletes the application. Deleting the application needs the same credential as `up`. If Clerk refuses the delete, `down` fails, and its fix is to run `down` again. Run `down` after a failed iteration too, so that no simulator or application stays behind.

```console
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios down
clerk   Platform API: 4 requests by this command so far, 1 application deleted
released  verify-ios-1
deleted   1 application (<application>, with every test user in it)
stopped   agent-device <pid>
kept      30 runs in .verify/runs/
```

The `deleted` line names the application. Its users and organizations go with it and get no lines of their own. `down --dry-run` changes nothing. It prints `would release`, `would delete`, and `would stop` lines, and under `would delete` one `application   <application>  (with every test user in it)` line for each application.

`down` never deletes `.verify/runs/`, and it prints how many runs it kept. Evidence lives inside the worktree, so `git worktree remove` deletes it with the rest. Copy the runs you need out first.

If a worktree is removed without `down`, the next `up` or `run` in any worktree on the same Mac finishes for it. That command deletes the removed worktree's lane simulator and application, stops its daemon, and prints one `reap` line for the lane and one for the removed worktree's ledger. [Files the CLI keeps](references/files.md) says where the ledger and the lane claims live.

## Helpers

- `bin/control-clerk-ios` is the CLI. It is executable, and every verb is shown above.
- `node .claude/skills/verify-clerk-ios/src/core/manifest.ts --write` rewrites `src/core/MANIFEST` after an intended change under `src/core/`. The Android and Expo verification skills share `src/core/` and must stay identical to it, so copy the directory to those two skills afterwards.
- `npm test --prefix .claude/skills/verify-clerk-ios` runs the CLI's unit tests, with no network, key, or simulator. `npm run typecheck --prefix .claude/skills/verify-clerk-ios` runs `tsc`. The `Run verify skill tests` job in `.github/workflows/shared-checks.yml` runs both on Linux. On a pull request, that job runs with the rest of PR CI, which a Clerk member can start with a `/run ci` comment. CI runs no device spec.
- To call `agent-device` yourself, use `node_modules/.bin/agent-device` in the skill directory with `AGENT_DEVICE_STATE_DIR=.claude/skills/verify-clerk-ios/.verify/agent-device`. Each worktree runs its own daemon from there, and `down` stops it. Never print `.verify/agent-device/daemon.json`, because it holds the daemon's auth token.
- e2e's AI judge is off, and golden specs never use it. [AI judge](references/ai-judge.md) says how to try it in an explored spec.
- `features/` is the feature map. Start with `features/README.md`.
