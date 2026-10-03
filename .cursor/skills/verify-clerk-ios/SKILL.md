---
name: verify-clerk-ios
description: Drive the clerk-ios SDK UI (AuthView, UserButton, UserProfileView, OrganizationSwitcher, session tasks) in the E2EHost app on a lane iOS simulator against a real Clerk dev instance, and capture video, screenshots, and host state as evidence. Use it to prove any change to ClerkKit, ClerkKitUI, or E2EHost works before calling it done, to reproduce a UI bug, or to run the golden regression specs.
---

# verify-clerk-ios

`bin/verify` is a control CLI over [e2e](https://github.com/tester-army/e2e) 0.15.2 and `@e2e-dev/mobile` 0.9.0. It builds E2EHost, leases a lane simulator, seeds `+clerk_test` users, runs specs, and keeps the evidence. Run every command from `.cursor/skills/verify-clerk-ios/`. Every verb takes `--json` and then prints one object. On success it is `{ "ok": true, "verb": "<verb>", ... }`, where `verb` names the verb and decides the remaining keys. On failure it is `{ "ok": false, "error": { "code", "message", "fix", "retryable" } }`. Exit codes are 0 for ok, 1 for spec failures, 2 for usage errors, and 3 for a failed precondition. Every error carries a `fix`.

The rule: no change to clerk-ios UI or auth behavior is done until a `bin/verify run` on the real host shows the changed behavior.

## Launch

```console
$ npm ci                       # once per worktree, before anything else
$ bin/verify doctor            # exits 3 until a build matches the current tree; on a clean machine build is the one failing check
$ bin/verify up                # build E2EHost for this tree, then lease verify-ios-<n> and install
build   ios-3f9a1c2e07b1  local  building...
build   ios-3f9a1c2e07b1  local  built in 58s
device  verify-ios-1  cloning Clerk Verify Template iOS
install ios-3f9a1c2e07b1  on verify-ios-1
device  verify-ios-1  local  leased by this worktree  installed ios-3f9a1c2e07b1
```

The lane is ready when `up` prints its last line, `device <name> local leased by this worktree installed <build key>`. The `device ... cloning` and `install` lines are progress. A reused build prints one `build <key> local reused` line. The build always finishes before `up` claims a lane, so a `wait` line for a full pool comes after the `build ... built` line.

`up` is idempotent. It reuses a build whose key matches the current tree (a hash of every tracked and modified file minus docs and specs) and a lease this worktree already holds. Any change to the tree, including reverting an edit, changes the key, so the next `up` or `run` rebuilds and reinstalls. It builds before it claims a lane, because a build needs no device. `run` calls `up` itself, so `up` exists to start the slow part early. To start the slow part early, run `bin/verify up --wait 600 &`, then `bin/verify run ...`. `run` prints one `wait` line naming the build, waits for the `up` to finish with no time limit, and uses its lease. `--wait` does not apply to that wait; it bounds waiting for a free lane and for another `run` that holds the device. Give the background `up` a `--wait`: on a full pool, an `up` without it builds, then exits 3 with `POOL_FULL`, and the `run` claims its own lane.

`run` prints the same ready line, `device <name> local leased by this worktree installed <build key>`, every time it holds a lease, whether it just leased the lane or reused one, before its `run <id>` line.

Builds are per worktree: they live in that worktree's `.verify/builds/`. Two worktrees at the same commit have the same build key and still each build once.

Before leasing, `up` and `run` release lanes whose claiming process is gone and whose worktree no longer exists, and print `reap    verify-ios-<n>  (owner process and worktree are gone)` for each.

Because `run` goes through the same lease step as `up`, a `run` also cleans up after worktrees that were removed without `down` (their lanes, users, and daemons), exactly as `up` does.

The lane simulator is a clone of `Clerk Verify Template iOS`, which trusts this Mac's proxy CA. The clone is deleted and re-cloned when a lease is lost or released, so the name `verify-ios-<n>` can map to a different UDID from one lease to the next. Read the UDID from `.verify/leases/ios.json`.

Never drive `iPhone Air`, the template, a physical device, or a simulator another worktree holds. Four lane simulators can exist on the Mac at once, across all agents. When all four are taken, `up` and `run` fail with `POOL_FULL`. Pass `--wait <seconds>` to either verb to wait for a lane. While waiting, the CLI prints one `wait` line naming the lanes in use, and prints it again only when that set changes.

Each worktree runs its own agent-device daemon from its own `node_modules`, with state under `.verify/agent-device/`. The CLI passes `AGENT_DEVICE_STATE_DIR` to e2e and to every `agent-device` call, and `down` stops the daemon. A daemon shared across worktrees breaks every worktree once the worktree that started it is removed. If you call `agent-device` yourself, set `AGENT_DEVICE_STATE_DIR=.verify/agent-device` and use `node_modules/.bin/agent-device`. To find this worktree's daemon pid, read the `would stop` line of `bin/verify down --dry-run`. Never print `.verify/agent-device/daemon.json`: it holds the daemon's auth token.

Teardown is `bin/verify down` (see Cleanup).

## Doctor

```console
$ bin/verify doctor --json
```

Run it first, and again whenever anything looks off. It is read-only. It checks:

- Node 24 and Xcode.
- `e2e-pins`: the installed e2e and `@e2e-dev/mobile` match the pinned versions. `agent-device-global`: the global `agent-device` matches the version `@e2e-dev/mobile` depends on.
- The template simulator. `proxy-trust`: when macOS has an HTTPS proxy on, the template must trust its CA. With no system HTTPS proxy, the check passes.
- The three instances' keys by name, and each instance's enabled strategies from `/v1/environment`. Keys come from `.keys.json` at the root of the main clerk-ios checkout, not the linked worktree. CI can pass `CLERK_TEST_KEYS_JSON` instead.
- Whether an E2EHost build matches the current tree.
- `gh pr comment --attach` support, stale device claims, and drift in `src/core/`.
- Whether an agent-device daemon, the Mac-wide one in `~/.agent-device` or this worktree's own, runs from an install that no longer exists. The fix names the pid to kill.
- Whether every feature in the Feature Map has its feature file and at least one golden spec.

A failing check prints the command that fixes it, and `doctor` exits 3. Before the first `up`, only `build` fails, with fix `bin/verify up`.

## Drive

Input only goes through specs. A spec is a TypeScript file that uses the `host` fixture from `specs/fixtures.ts` and e2e's `screen` locators.

```console
$ bin/verify run auth-start                        # one feature (specs/golden/auth-start/)
$ bin/verify run sign-up/request-code              # one spec
$ bin/verify run specs/explored/resend.e2e.ts      # a spec you wrote
$ bin/verify run --all --skip form-entry           # every golden spec except form entry
$ bin/verify run sign-up --skip form-entry         # one feature without its form-entry spec
$ bin/verify run auth-start sign-up organizations  # several targets in one run, one lease, one video
$ bin/verify screen                                # current UI tree with testIds and VerifyState
$ bin/verify screen --png                          # plus a screenshot in scratch
```

`run` flags are `--skip form-entry`, `--include known-bug`, `--grep <regex>`, `--no-video`, and `--wait <seconds>` (how long to wait for a free lane or for another verb in this worktree that holds the device).

The `host` fixture:

```ts
import { test, expect, CLERK_TEST_CODE } from '../../fixtures.ts';

test('profile shows the seeded user', async ({ host, screen }) => {
  const user = await host.seedUser({ instance: 'with-email-codes' });         // BAPI user, ledgered for cleanup
  const state = await host.launch({ signedInAs: user, screen: 'userProfile' }); // ticket sign-in, fresh storage
  expect(state.userId).toBe(user.id);
  await expect(screen.getByText(user.email)).toBeVisible();
  await host.screenshot('profile');                                           // runs/<id>/screenshots/profile.png
});
```

- `host.launch({ instance | signedInAs, screen?, authMode?, debugLogs?, keepStorage? })` relaunches E2EHost with launch arguments and returns the first `VerifyState` for that launch that is ready. Every launch starts with fresh storage, so a launch with `instance` and no `signedInAs` is signed out, on `home` or any other screen. Screens are `home`, `auth`, `userProfile`, `orgSwitcher`, `orgList`, and `orgProfile`. Auth modes are `signIn`, `signUp`, and `signInOrUp`.
- `host.seedUser({ instance, phone? })` creates a `+clerk_test` user. `host.newEmail(instance)` reserves an email for a form sign-up.
- `host.state()` reads the footer. `host.waitForState(predicate, timeoutMs?)` polls it. The footer is not readable while a sheet covers the host.
- `host.tap(locator)` taps the middle of the node's box, and `host.fill(locator, text)` taps it and types `text` into the focused field. Use them for every action inside AuthView, UserProfileView, and organization sheets. On iOS 27 a SwiftUI toolbar adds a hittable full-screen `Toolbar` node, and agent-device 0.21.18 refuses `locator.tap()` and `locator.fill()` under it with "covered by another visible element". Plain locator actions still work on the E2EHost home screen.
- The footer `verify.state` holds `verify ` plus one line of JSON: `screen`, `environmentLoaded`, `signedIn`, `userId`, `sessionId`, `sessionStatus`, `pendingTasks`, `orgId`, `signInStatus`, `signUpStatus`, `ticket`, `lastError`, `runId`, and `launchId`. `screen` is what is on screen, not what was asked for. `signedIn` is true for a pending session, so read `sessionStatus`. The footer shows in screenshots and videos. Its ids, `sessionId` included, are not secrets: a session id cannot sign anyone in. Sealing still searches every evidence file for the real secrets a run used (secret keys and tickets) and blocks `attach` on a hit.
- Locate with SDK identifiers, `screen.getByTestId('clerk.auth.start.identifier')`. The full list is in `Sources/ClerkKitUI/Components/Auth/ClerkAccessibilityIdentifiers.swift`. E2EHost adds `e2e.auth.signIn`, `verify.signOut`, `verify.userId`, and `verify.state`.

There are two ways to check work.

1. **Golden specs** under `specs/golden/<feature>/` are committed, cover the Feature Map in `features/`, and run unchanged as regression. Run the features your change touches.
2. **New work.** Write a spec under `specs/explored/` (gitignored), run it, and read the end state with `bin/verify screen`. Call `screen` after any run, passing or failing, whenever you need the next locator: after a pass it shows the screen the spec ended on, which is where the next step of new work starts. `screen` works right after `up` too, but the app then runs without launch arguments, so it shows the `error` screen (no publishable key). To look at a real screen, run a spec that launches it first, even one that only calls `host.launch`. `screen.getByTestId` matches any accessibility identifier, the SDK's `clerk.*` ids and E2EHost's own plain strings such as `e2e.auth.signIn` or an id you add for a probe. Fix locators from the `screen` output until it passes. The PR commits that spec into `specs/golden/<feature>/` and updates the feature file when the change adds or changes a user-facing behavior. Otherwise the spec stays with the run evidence (`runs/<id>/specs/` keeps a copy of every spec a run used).

An explored spec sits one level below `specs/`, so it imports the fixture as `../fixtures.ts`, where a golden spec uses `../../fixtures.ts`:

```ts
import { test, expect } from '../fixtures.ts';
```

A failing spec prints `FAIL`, the first assertion message, and the path of its failure page, and `run` exits 1. The failure page (`runs/<id>/e2e/failures/*.md`) lists every step, the screen tree at the failure, and a screenshot. `next` points at it.

```console
$ bin/verify run specs/explored/resend-countdown.e2e.ts
  FAIL  explored/resend-countdown.e2e.ts  shows the resend countdown  14.1s
        expect.toBeVisible failed; locator: getByTestId("clerk.auth.code.resend"); expected: visible; observed: no node (match count 0)
        failure page  .verify/runs/r20261003-020926-ba6f/e2e/failures/specs_explored_resend-countdown.e2e.ts-....md
$ bin/verify screen
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
- **Phones.** Any US number from 555-0100 to 555-0199 is a test number. Type it as ten digits, for example `5555550142`. The numbers are shared across repos, CI, and agents, so get one from `host.seedUser({ instance, phone: true })` instead of picking one by hand.
- **One-time code.** `424242` verifies every email code and SMS code for test addresses and phones. Specs use the constant `CLERK_TEST_CODE`. It is public, so it is not an e2e secret, and screenshots after the fill are kept.
- **Passwords.** `with-email-codes` (the `all-enabled` instance) requires a password at sign-up. Use a throwaway per run, such as `Verify-<runId>-Pw1!`.
- **Authenticator (TOTP) codes.** Read the setup key from `clerk.auth.sessionTask.totp.secret`, then compute the 6-digit code with RFC 6238 (SHA-1, 30 second step). `specs/golden/session-tasks/complete-setup-mfa.e2e.ts` has a helper.

| Instance key in `.keys.json` | Use it for |
| --- | --- |
| `with-email-codes` (the `all-enabled` instance) | Every auth method and every signed-in feature: email code, email link, phone code, password, username, TOTP, backup codes, organizations, social buttons. |
| `with-session-tasks-setup-mfa` | Sign-ins that must stop on the "set up MFA" session task. MFA is required for every user there. |
| `with-session-tasks` | Sign-ins that must stop on the "choose or create an organization" session task. |

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
  const user = await host.seedUser({ instance: 'with-email-codes' });
  await host.launch({ instance: 'with-email-codes', screen: 'auth', authMode: 'signIn' });
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

On `with-email-codes` an email sign-in starts on the email-link screen, so the spec switches to the email code through `Use another method`. For a phone sign-in, tap `clerk.auth.start.identifierSwitcher`, fill `clerk.auth.start.phoneNumber` with the seeded user's phone, continue, and type the same code. For sign-up, launch with `authMode: 'signUp'`, fill the email from `host.newEmail('with-email-codes')` into `clerk.auth.start.identifier`, continue, type the code into `clerk.auth.signUp.code`, then the run password.

Rules:

- Type only `+clerk_test` emails, 555-0100 to 0199 phones, and `424242`. Never a real person's address, number, or password. The repo is public, and every video lands on a PR.
- Use ticket sign-in (`host.launch({ signedInAs })`) only to reach signed-in screens for features that are not about authentication. A change to an auth method gets a spec that drives the real form.
- Tag every spec that types a code `form-entry`. Those specs run by default. An agent runtime that refuses to type codes into an app that talks to hosted Clerk runs `bin/verify run --skip form-entry`, which reports them as `skipped by --skip form-entry`, and says so in the PR. CI runs the skipped specs.
- Tag a golden spec that reproduces an open SDK bug `known-bug`, with a title that names the bug. e2e has no expected-failure status, so `run` leaves `known-bug` specs out unless you pass `--include known-bug`, and reports them as `skipped: known-bug`. A tag on both wins over `form-entry`. A feature whose only golden spec is `known-bug` still passes the Feature Map check. Remove the tag in the PR that fixes the bug.
- The form-entry specs, one command each: `bin/verify run sign-in-email-code/complete`, `bin/verify run sign-up/complete`, and `bin/verify run session-tasks/complete-setup-mfa`.
- `bin/verify down` deletes every user the run created, including users created through the sign-up form, by their test email.

## Evidence

Every `run` writes `.verify/runs/<run-id>/` and prints its path:

| File | What it is |
| --- | --- |
| `run.json` | The sealed record: `results` per spec, `gitHead`, `dirty`, `build` (the build key), `device`, `identities`, and `tainted` files |
| `video.mp4` | `simctl io recordVideo` of the whole run |
| `screenshots/<label>.png` | Every `host.screenshot(label)` |
| `states.jsonl` | Every `VerifyState` the fixture read, in order, across every test in the run |
| `state.json` | Only the last state of the whole run. With several tests, read per-test states from `states.jsonl` by `launchId`. The run summary's `last state` line shows the same single state |
| `app.log` | `com.clerk.verify` and `com.clerk.sdk` log lines from the run (network lines only with `debugLogs: true`) |
| `e2e/` | e2e's `report.json`, failure pages, and `screen.txt` for failed steps |
| `e2e.log` | e2e's console output |
| `specs/` | A copy of every spec the run used |

Proof standards: drive the real user path, capture the action and the resulting state (the video plus `states.jsonl`), and check side effects in `states.jsonl` (`userId`, `orgId`, `pendingTasks`), not only the final screen.

After a run, sealing searches the run directory for every secret the run used (secret keys, tickets). A hit marks the file tainted in `run.json`, and a tainted run cannot be attached.

```console
$ bin/verify attach <run-id> --pr <n>                       # video and every screenshot
$ bin/verify attach <run-id> --pr <n> --screenshot profile  # video and one screenshot
```

`attach` posts once per run with `gh pr comment --attach`. It refuses a run that is tainted, failed, or shows a user id the run did not create.

## Cleanup

```console
$ bin/verify down --dry-run   # what it would release, stop, and delete: each user (instance, id, test email) and organization (instance, id, name)
$ bin/verify down             # release the simulator, delete run users and their organizations, stop recorders and this worktree's agent-device daemon
$ bin/verify down --stale     # also finish cleanup left by a crashed run in this worktree
```

`down` deletes only what this worktree created: its lane simulator and the users in its ledger. Ledgers live at `~/.verify/ledgers/<id>.jsonl`, where `<id>` is a hash of the worktree path, and `<id>.owner` beside it holds the path. Find yours with `grep -l "$(git rev-parse --show-toplevel)" ~/.verify/ledgers/*.owner`. It never deletes `.verify/runs/`. Evidence survives teardown at `.cursor/skills/verify-clerk-ios/.verify/runs/<run-id>/`, and `down` lists the kept runs. Run `down` after a failed iteration too, so no simulator is stranded.

Evidence lives inside the worktree. `git worktree remove` deletes `.verify/runs/` with the rest of the worktree, so copy the runs you need out first.

If a worktree is removed without `down`, the next `up` or `run` in any worktree finishes for it. It deletes that worktree's lane simulator and the users in its ledger, stops its agent-device daemon, and prints `reap ledger of <path> ... deleted N users, M organizations, stopped agent-device <pid>`. Then it marks every open ledger entry done. The ledger files stay on disk.

A ledger can number a test email that never became a user: a sign-up spec that stops at the code screen reserves `verify_<run>_<n>` but creates nothing. `down` finds no user for it and deletes 0, which is correct.

`down --dry-run --json` and `down --json` print different shapes. A dry run prints `{ dryRun: true, wouldRelease, wouldDelete, wouldStop, keptRuns }`, where `wouldDelete` lists `{ kind: 'user', instance, id, email }` and `{ kind: 'organization', instance, id, name }` entries. A real `down` prints `{ dryRun: false, released, deletedUsers, deletedOrganizations, stoppedProcesses, keptRuns }`. Lane slots are machine-wide claims under `~/.verify/claims/`. A slot changes hands only by compare-and-swap, so two worktrees never hold the same lane.

## Helpers

- `bin/verify` is the only helper. It is executable. Every invocation is shown above.
- `e2e.config.ts` composes the e2e config from the CLI's run context. `npx e2e list` works from this directory while a lease is held.
- `specs/fixtures.ts` is the `host` fixture. It takes its screen names from `src/host.ts`, so it is the same file in every repo.
- `npm test` runs the CLI's unit tests (`node --test test/*.test.ts`), with no network, keys, or simulator. `testing/` holds helper processes those tests spawn; they are not tests themselves. `npm run typecheck` runs `tsc`.
- `features/` is the Feature Map. Start with `features/README.md`.

Keep the map honest with `/maintain-verification-skill`.
