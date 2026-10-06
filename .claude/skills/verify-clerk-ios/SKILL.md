---
name: verify-clerk-ios
description: Drive the clerk-ios SDK UI (AuthView, UserButton, UserProfileView, OrganizationSwitcher, session tasks) in the E2EHost app on an iOS simulator against a real Clerk development instance that the session creates and deletes, and capture video, screenshots, and the app log as evidence. Use it to prove any change to ClerkKit, ClerkKitUI, or E2EHost works before calling it done, to reproduce a UI bug, or to run the golden regression specs.
---

# verify-clerk-ios

`.claude/skills/verify-clerk-ios/bin/control-clerk-ios` is a control CLI over [e2e](https://github.com/tester-army/e2e). It builds E2EHost, leases a simulator, creates one Clerk application for the worktree, seeds `+clerk_test` users, runs specs, and keeps the evidence.

No change to clerk-ios UI or auth behavior is done until a `run` in E2EHost shows the changed behavior.

Run every command from the repo root. In the prose below, `doctor`, `up`, `run`, `screen`, `attach`, and `down` are verbs of that CLI. Paths that begin `specs/`, `features/`, `references/`, `src/`, or `.verify/` are inside `.claude/skills/verify-clerk-ios/`. Every error prints a `fix` line. Every verb takes `--json`, and [CLI output](references/output.md) has its shape and the exit codes.

## Launch

Set up each machine once.

1. Install Node 24, at 24.8.0 or newer, and Xcode with an iOS simulator runtime.
2. Create the template simulator, which the CLI clones to make each simulator it drives, for example with `xcrun simctl clone "iPhone Air" "Clerk Verify Template iOS"`.
3. Give the machine the team's Clerk Platform API key. Set `CLERK_PLATFORM_API_KEY`, or set `CLERK_PLATFORM_API_KEY_FILE` to a file that only you can read (mode 0600). With neither set, the CLI reads the key from 1Password through the secret reference in `VERIFY_PLATFORM_KEY_REFERENCE`. A command that reads the key from 1Password waits up to 60 seconds for a person to approve the request in the 1Password app. Never put the key in a file inside a repository.

Then, in each worktree:

```console
$ npm ci --prefix .claude/skills/verify-clerk-ios                 # once per worktree
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios doctor
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios up
backend local  this Mac runs the simulator itself
device  verify-ios-<n>  local  leased by this worktree  installed <build key>
```

`up` builds E2EHost for the current tree, creates this worktree's Clerk application, clones the template into a simulator named `verify-ios-<n>`, and installs the build. It prints a line for each step. The simulator is ready when `up` prints the `device` line above, which is its last line. `run` does the same steps itself and prints the same line, so `up` only starts the slow part early. Teardown is `down` (see [Cleanup](#cleanup)).

`up` is idempotent. It keeps a lease this worktree already holds, and it reuses a build whose key matches the current tree. The key is a hash of the tracked and untracked files under `Sources`, `Examples/E2EHost`, `Package.swift`, and `Clerk.xcworkspace`, minus Markdown. A change to any of those files changes the key, so the next `up` or `run` builds that key, unless this worktree already built it, and reinstalls.

The Clerk application is this worktree's own. `up` creates it through Clerk's Platform API, in the team's verification workspace, and puts its development instance on the standard settings in `src/core/instances/base.json`. It holds only the users that this worktree's runs create, and `down` deletes it. A spec file that needs other settings declares them (see [Drive](#drive)). [Test instances](references/instances.md) has the credential lookup, the application's lifetime, and its limits.

The CLI drives only `verify-ios-<n>`, which it creates. A Mac has four of these simulators, shared by every worktree on it. When all four are taken, `up` and `run` fail with `POOL_FULL`, and `--wait <seconds>` on either verb waits for one.

## Doctor

```console
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios doctor
```

Run it first, and again whenever anything looks off. Without `--live` it only reads. It creates no file, no simulator, and no Clerk application. Each line starts with `ok`, `warn`, `skip`, or `FAIL`, then has the id of the check and what the check found. `skip` marks a check that did not run, and its text starts with `not run:`. A failing check also prints a `fix:` line with the command to run, and `doctor` exits 3. A warning does not change the exit code.

After the once-per-machine setup and before the first `up`, `build` is the one failing check, and its fix is `up`. A machine with no Platform API credential fails `instances`, and the fix line says how to supply one. `doctor --live` also proves that the credential can create, configure, and delete an application. It creates one application, configures it, compares it with the standard file, and deletes it, and reports that in a `live-instance` line.

## Drive

Input reaches the app only through specs. A spec is a TypeScript file that uses the `host` fixture from `specs/fixtures.ts` and e2e's `screen` locators.

```console
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios run auth-start                        # one feature: every spec in specs/golden/auth-start/
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios run sign-up/complete                  # one golden spec
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios run specs/explored/<name>.e2e.ts      # a spec you wrote
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios run auth-start sign-up organizations  # several targets in one run, with one video
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios screen                                # the UI tree that is on screen now; --png adds a screenshot
```

`run` also takes `--grep <regex>`, `--retries <n>`, `--no-video`, and `--wait <seconds>`. `--retries <n>` runs a failed test again, up to `n` more times. The default is 0, so a run of your own change shows exactly what happened. The wait covers a free simulator and another `run` in this worktree that holds the device.

### Sign in with the form or with a ticket

A change that touches sign-in or sign-up gets a spec that drives the real form with a `+clerk_test` identity and the test code. Any other change reaches a signed-in state with a sign-in ticket, `host.launch({ signedInAs: user })`.

Type only test identities: `+clerk_test` emails, phone numbers 555-0100 to 555-0199, and the code `424242`, which specs import as `CLERK_TEST_CODE`. Never type a real person's address, number, or password. [The feature map index](features/README.md) lists the test identities and the identifier for each step of the forms.

### Write a spec

```ts
import { test, expect } from '../../fixtures.ts';

test('the home UserButton opens the profile of the signed-in user', async ({ host, screen }) => {
  const user = await host.seedUser();
  await host.launch({ signedInAs: user });
  await host.tap(screen.getByTestId('clerk.userButton.profile'));
  await host.tap(screen.getByTestId('clerk.userProfile.row.manageAccount'));
  await expect(screen.getByText(user.email)).toBeVisible({ timeout: 20_000 });
  await host.screenshot('profile');
});
```

- `host.seedUser({ phone?, password? })` creates a `+clerk_test` user in the worktree's application. With `password: true` the user also has a password that the run generated for that user, and `user.password` holds it. Pass it to `host.fill`, as `host.fill(field, user.password!)`, and to nothing else. It prints as `<secret:password>`, `run` redacts its value from the logs it writes, and `attach` refuses a run whose files hold it. `host.newEmail()` reserves an address, and `host.newPhone()` a 555-01xx number, for a sign-up through the form.
- `host.launch({ signedInAs?, authMode?, initialIdentifier?, debugLogs?, keepStorage?, landsOn? })` relaunches E2EHost and waits up to 60 seconds for its home. Every launch opens on the home, and a spec taps from there to the view it needs, as a user does. `authMode` is the mode of both AuthViews the home opens: `signIn`, `signUp`, or `signInOrUp`. `initialIdentifier` is the email, username, or phone number that the full-screen AuthView gets through `AuthView().initialIdentifier(_:)`. A launch starts with fresh storage unless `keepStorage` is true, so a launch with no `signedInAs` is signed out and lands on the home's `Sign in` button. A launch with `signedInAs` lands on the home, which must show that user's email and user ID. When the home should show anything else, pass its locator as `landsOn`. Two launches need it: one that signs in a user whose session stays pending on a task, where the home shows `Signed out`, and one that keeps storage and has no `signedInAs`. `host.launch` fails at once when the app shows its error screen, and the error has the message on that screen.
- `host.expectSignedInAs(user, timeoutMs?)` waits for the home to show `Signed in as <email>`, the user's ID, and a session ID. Pass the email alone for a user that the sign-up form created. `host.expectSignedOut(timeoutMs?)` waits for the home to show `Signed out` with no user ID and no session ID. Use them for the outcome of a flow that returns to the home.
- `host.app` has the locators of the home: `signIn`, `signInFullScreen`, `signedOut`, `signedIn`, `userId`, `sessionId`, `signOut`, and `error` for the error screen. `host.runId` is the id of the run, for a name or a password that must be new in each run.
- `host.tap(locator)` is `locator.tap()` with the assertion timeout, and `host.fill(locator, text)` taps a field and types into it. When the first tap left no field focused, it taps the field once more before it types. Fill every SDK text field with `host.fill`. An SDK text field shows no text input until it has focus, so a plain `locator.fill()` on an email or name field fails with "no text input found at the provided coordinates to clear". After it types, `host.fill` reads the focused text input back. If the input is still empty after two seconds, `host.fill` taps it and types once more, and it fails with "the text never reached the field" if the input is empty again. If the input holds something other than the text, `host.fill` replaces the input's contents with the text once, and it fails with "the field does not hold the typed text" if the input is still wrong. It compares letters and digits only, so the formatting a field adds does not count. A secure field withholds its value, so a password is typed once and is not confirmed.
- `host.screenshot(label)` writes `screenshots/<label>.png` in the run directory.

Assert on what a user sees, and look in the SDK's own views first. The code screen names the address the code went to. A session task is on screen while the session is pending. The profile and the account sheet of a task view show the email of the signed-in user. The OrganizationSwitcher shows the active organization. Use E2EHost's home for a fact that no SDK view shows, and for the outcome of a flow that returns to the home.

The home is E2EHost's own screen. With no active session it shows `Signed out` (`e2e.auth.signedOut`) and two buttons. `Sign in` (`e2e.auth.signIn`) opens AuthView in a sheet. `Sign in full screen` (`e2e.auth.signInFullScreen`) shows `AuthView(isDismissible: false)` as the root of the window, which is how an app shows AuthView until `clerk.isAuthFlowComplete`. With an active session it shows the UserButton, `Signed in as <email>` (`e2e.auth.signedIn`), the user ID (`e2e.auth.userId`), the session ID (`e2e.auth.sessionId`), the OrganizationSwitcher, and a `Sign out` button (`e2e.auth.signOut`). A pending session counts as signed out there, and either button opens AuthView on the task. E2EHost shows the home again when the full-screen AuthView completes its flow. It draws nothing on or around an SDK view. While Clerk loads or a ticket signs in, it shows a spinner. When a launch cannot start, it shows `Something went wrong` and the reason (`e2e.launch.error`).

E2EHost has a small flow of its own only where the SDK has no view for one. `Sign out` calls `clerk.auth.signOut()`. When a change needs a fact or a flow that no SDK view covers, add it to the home the way a real app would show it, and assert on that.

Locate nodes with `screen.getByTestId(...)`. The SDK's identifiers start with `clerk.`, and `Sources/ClerkKitUI/Components/Auth/ClerkAccessibilityIdentifiers.swift` lists them. E2EHost's own identifiers start with `e2e.`, and `Examples/E2EHost/E2EHost/E2EIdentifiers.swift` lists them. All of these identifiers are internal test hooks, not public API, and they can change. Every spec keeps at least one exact assertion on an identifier or on visible text.

A spec file that needs other settings than the standard ones declares them in a JSON file beside it, which has the name of the spec with `.settings.json` in place of `.e2e.ts`. `run` puts the application on those settings before the tests in that spec file start. [Test instances](references/instances.md) has the rules for a declaration.

### Check your work

Golden specs under `specs/golden/<feature>/` are committed and cover the feature map in `features/`. Prove your own change, and leave the rest of the golden specs to the release workflow (`.github/workflows/release-sdk.yml`), which runs every one of them before an SDK version is published. When your change is to behavior a golden spec already covers, that spec is your proof: run it. Run another feature's specs yourself when you changed code that feature shares, because nothing else runs them before the release. For new work:

1. Write a spec under `specs/explored/`, which is gitignored. It imports the fixture as `'../fixtures.ts'`.
2. Run it by path.
3. Run `screen` after the run, pass or fail. It prints the tree the app is on now, one line per node with its role, label, `id=<identifier>`, and a ready `screen.getByTestId('<identifier>')` when the identifier is unique.
4. Fix the locators from that output until the spec passes.
5. When the change adds or changes user-facing behavior, move the spec to `specs/golden/<feature>/` with its settings file if it has one, change its import to `'../../fixtures.ts'`, `git add` both, and update the feature file. Otherwise leave it where it is. The run directory keeps a copy of every spec the run used.

A failing spec prints `FAIL`, the first assertion message, and the path of its failure page, and `run` exits 1. The failure page (`.verify/runs/<run-id>/e2e/failures/*.md`) lists every step, the screen tree at the failure, and a screenshot. The `next` line of the run points at it.

With `--retries`, a test that fails and then passes prints `flaky` and the error of its failed attempt, and a `flaky` line under the results counts such tests. `run.json` records the test as `flaky` with its `attempts`, never as passed, and `run` exits 0. The failure page of the failed attempt and the files of every attempt stay in the run directory. A test that fails on every attempt prints `FAIL`, and `run` exits 1.

Right after `up` the app has no launch arguments, so `screen` shows the host's error screen. To look at a real screen, first run a spec that launches the app and taps to it. When a node may be missing, assert `await expect(locator).toBeVisible()` before you tap it. That failure reads `observed: no node (match count 0)`, and a failed tap says only `LOCATOR_NOT_FOUND`.

### Agent steps

e2e has a built-in agent, which a test drives with `agent.act(...)` and `agent.assert(...)`. The CLI configures it only when the machine has a Vercel AI Gateway key. The model is `anthropic/claude-haiku-5.5`, and `openai/gpt-6-luna-fast` is the gateway's backup. Supply the key in `AI_GATEWAY_API_KEY_FILE`, a file that only you can read, or in `AI_GATEWAY_API_KEY`. The `agent` line of `doctor` shows the model and where the key came from. Committed golden specs do not use agent steps.

## Evidence

Every `run` writes `.verify/runs/<run-id>/` and prints its path.

| File | What it holds |
| --- | --- |
| `run.json` | The sealed record: `results` per spec, `gitHead`, `dirty`, `build`, `device`, `identities`, `settings`, and `tainted` |
| `video.mp4` | `simctl io recordVideo` of the whole run |
| `screenshots/<label>.png` | Every `host.screenshot(label)` |
| `app.log` | The `com.clerk.verify` and `com.clerk.sdk` log lines of the run. E2EHost writes one `com.clerk.verify` line each time its screen, user, session, or launch error changes, with the `launchId` that a failed `host.launch` names. No spec reads these lines. They are for diagnosing a failure that the screen does not explain. The SDK logs errors only, unless the launch passes `debugLogs: true` |
| `e2e/`, `e2e.log` | e2e's `report.json` and `junit.xml`, its failure pages, and its console output. A run with several settings groups also has `e2e-2/`, `e2e-3/`, and so on |
| `specs/` | A copy of every spec the run used, and of its settings file |

A proof drives the real user path. The video and the screenshots show the action and its result as a user sees them. It checks side effects where the app shows them, such as the user ID on the home or the organization name on the switcher, not only that the last screen appeared.

After a run, the CLI searches the run directory for every secret the run used: the Platform API key, the instance's secret key, sign-in tickets, and a GitHub token in `GITHUB_TOKEN` or `GH_TOKEN`. A hit marks the file as tainted in `run.json`. The user ID and the session ID on the home are not secrets, because neither can sign anyone in.

A machine with no `gh` can still run and keep evidence. Name the run id in the PR and say that the evidence was not attached.

```console
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios attach <run-id> --pr <n>                       # the video and every screenshot
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios attach <run-id> --pr <n> --screenshot profile  # the video and one screenshot
```

`attach` posts one comment per run and PR with `gh pr comment --attach`. It needs a `gh` whose `gh pr comment` has that flag, and it fails with a fix when the flag is missing. It refuses a run that is tainted, that has a failing spec or no passing one, or whose `app.log` names a user that the run did not create.

Attach the run of your own change. Run your new or changed spec on its own and attach that run, so the PR video shows only the behavior the change is about. If you ran other golden specs too, cite that run's id in the PR.

## Cleanup

```console
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios down --dry-run  # what it would release, delete, and stop
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios down            # release the simulator, delete this worktree's application, stop its processes
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios down --stale    # also release a simulator that a crashed run here, or a deleted worktree, left claimed
```

`down` removes only what this worktree created: its simulator, its Clerk application with every user and organization in it, the video recorder, and its agent-device daemon. It releases the simulator before it deletes the application. Deleting the application needs the same credential as `up`. If Clerk refuses the delete, `down` fails, and its fix is to run `down` again. Run `down` after a failed iteration too, so that no simulator or application stays behind.

```console
$ .claude/skills/verify-clerk-ios/bin/control-clerk-ios down
released  verify-ios-1
deleted   1 application (<application>, with every test user in it)
stopped   agent-device <pid>
kept      30 runs in .verify/runs/
```

The `deleted` line names the application. Its users and organizations go with it and get no lines of their own. `down --dry-run` changes nothing. It prints `would release`, `would delete`, and `would stop` lines, and under `would delete` one `application   <application>  (with every test user in it)` line for each application.

`down` never deletes `.verify/runs/`, and it prints how many runs it kept. Evidence lives inside the worktree, so `git worktree remove` deletes it with the rest. Copy the runs you need out first.

If a worktree is removed without `down`, the next `up` or `run` in any worktree on the same Mac finishes for it. That command deletes the removed worktree's simulator and application, stops its daemon, and prints a `reap` line for each.

## For maintainers of the skill

- The Android and Expo verification skills share `src/core/`, and it is copied to them. After a change under `src/core/`, `node .claude/skills/verify-clerk-ios/src/core/manifest.ts --write` rewrites `src/core/MANIFEST`.
- `npm test --prefix .claude/skills/verify-clerk-ios` runs the CLI's unit tests, with no network, key, or simulator. `npm run typecheck --prefix .claude/skills/verify-clerk-ios` runs `tsc`. The `Run verify skill tests` job in `.github/workflows/shared-checks.yml` runs both on Linux.
- `.github/workflows/verify-e2e.yml` runs `up`, `run --all --retries 1 --github-report`, and `down` on a simulator on a CI runner. It needs the repository secret `MOBILE_VERIFICATION_PLATFORM_API_KEY`. It runs on the `xcode-27` label unless the repository variable `VERIFY_CI_RUNNER` names another. `gh workflow run verify-e2e.yml --ref <branch>` starts it by hand.
- `run --github-report` hands the results of a run to `@e2e-dev/github`, which writes them to the job summary and to one pull request comment.
