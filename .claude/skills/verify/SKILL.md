---
name: verify
description: Drive the clerk-ios SDK UI (AuthView, UserButton, UserProfileView, OrganizationSwitcher, session tasks) in the E2EHost app on a lane iOS simulator against a real Clerk dev instance, and capture video, screenshots, and host state as evidence. Use it to prove any change to ClerkKit, ClerkKitUI, or E2EHost works before calling it done, to reproduce a UI bug, or to run the golden regression specs.
---

# verify

`bin/verify` is a control CLI over [e2e](https://github.com/tester-army/e2e) 0.15.2 and `@e2e-dev/mobile` 0.9.0. It builds E2EHost, leases a lane simulator, seeds `+clerk_test` users, runs specs, and keeps the evidence. Run every command from `.claude/skills/verify/`. Every verb takes `--json` and then prints one `{ "ok": ... }` object. Exit codes are 0 for ok, 1 for spec failures, 2 for usage errors, and 3 for a failed precondition. Every error carries a `fix`.

The rule: no change to clerk-ios UI or auth behavior is done until a `bin/verify run` on the real host shows the changed behavior.

## Launch

```console
$ npm ci                       # once per worktree
$ bin/verify up                # build E2EHost for this tree, lease verify-ios-<n>, install
build   ios-3f9a1c2e07b1  local  58s
device  verify-ios-2  local  slot 2 of 4  leased by this worktree
```

`up` is idempotent. It reuses a build whose key matches the current tree (a hash of every tracked and modified file minus docs and specs) and a lease this worktree already holds. `run` calls `up` itself, so `up` exists to start the slow part early. Ready means `up` printed a `device` line. The lane simulator is a clone of `Clerk Verify Template iOS`, which trusts this Mac's proxy CA.

Never drive `iPhone Air`, the template, a physical device, or a simulator another worktree holds. Four lane simulators can exist on the Mac at once, across all agents. When all four are taken, `up` fails with `POOL_FULL`. Pass `--wait <seconds>` to wait for a slot.

Teardown is `bin/verify down` (see Cleanup).

## Doctor

```console
$ bin/verify doctor --json
```

Run it first, and again whenever anything looks off. It is read-only. It checks Node 24, Xcode, the pinned e2e and agent-device versions against the global `agent-device`, the template simulator, the macOS proxy against the template's trust store, the three instances' keys by name, each instance's enabled strategies from `/v1/environment`, whether an E2EHost build matches the current tree, `gh pr comment --attach` support, stale device claims, and drift in `src/core/`. A failing check prints the command that fixes it. Before the first `up`, only `build` fails, with fix `verify up`.

## Drive

Input only goes through specs. A spec is a TypeScript file that uses the `host` fixture from `specs/fixtures.ts` and e2e's `screen` locators.

```console
$ bin/verify run auth-start                        # one feature (specs/golden/auth-start/)
$ bin/verify run sign-up/request-code              # one spec
$ bin/verify run specs/explored/resend.e2e.ts      # a spec you wrote
$ bin/verify run --all --skip form-entry           # every golden spec except form entry
$ bin/verify screen                                # current UI tree with testIds and VerifyState
$ bin/verify screen --png                          # plus a screenshot in scratch
```

`run` flags are `--skip form-entry`, `--grep <regex>`, and `--no-video`.

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

- `host.launch({ instance | signedInAs, screen?, authMode?, debugLogs?, keepStorage? })` relaunches E2EHost with launch arguments and returns the first `VerifyState` for that launch that is ready. Screens are `home`, `auth`, `userProfile`, `orgSwitcher`, `orgList`, and `orgProfile`. Auth modes are `signIn`, `signUp`, and `signInOrUp`.
- `host.seedUser({ instance, phone? })` creates a `+clerk_test` user. `host.newEmail(instance)` reserves an email for a form sign-up.
- `host.state()` reads the footer. `host.waitForState(predicate, timeoutMs?)` polls it. The footer is not readable while a sheet covers the host.
- `host.tap(locator)` taps the middle of the node's box, and `host.fill(locator, text)` taps it and types `text` into the focused field. Use them for every action inside AuthView, UserProfileView, and organization sheets. On iOS 27 a SwiftUI toolbar adds a hittable full-screen `Toolbar` node, and agent-device 0.21.18 refuses `locator.tap()` and `locator.fill()` under it with "covered by another visible element". Plain locator actions still work on the E2EHost home screen.
- The footer `verify.state` holds `verify ` plus one line of JSON: `screen`, `environmentLoaded`, `signedIn`, `userId`, `sessionId`, `sessionStatus`, `pendingTasks`, `orgId`, `signInStatus`, `signUpStatus`, `ticket`, `lastError`, `runId`, and `launchId`. `screen` is what is on screen, not what was asked for. `signedIn` is true for a pending session, so read `sessionStatus`.
- Locate with SDK identifiers, `screen.getByTestId('clerk.auth.start.identifier')`. The full list is in `Sources/ClerkKitUI/Components/Auth/ClerkAccessibilityIdentifiers.swift`. E2EHost adds `e2e.auth.signIn`, `verify.signOut`, `verify.userId`, and `verify.state`.

There are two ways to check work.

1. **Golden specs** under `specs/golden/<feature>/` are committed, cover the Feature Map in `features/`, and run unchanged as regression. Run the features your change touches.
2. **New work.** Write a spec under `specs/explored/` (gitignored), run it, and read the end state with `bin/verify screen`. Fix locators from the `screen` output until it passes. The PR commits that spec into `specs/golden/<feature>/` and updates the feature file when the change adds or changes a user-facing behavior. Otherwise the spec stays with the run evidence (`runs/<id>/specs/` keeps a copy of every spec a run used).

```console
$ bin/verify run specs/explored/resend-countdown.e2e.ts
  FAIL  explored/resend-countdown.e2e.ts  shows the resend countdown
$ bin/verify screen
button  "Resend (29)"   id=clerk.auth.code.resend   screen.getByTestId('clerk.auth.code.resend')
$ git mv specs/explored/resend-countdown.e2e.ts specs/golden/sign-up/
```

Every spec keeps at least one exact assertion on `verify.state` or an SDK identifier.

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
| Try another method | `clerk.auth.signIn.useAnotherMethod` |
| Sign-up email, password, continue | `clerk.auth.signUp.emailAddress`, `clerk.auth.signUp.password`, `clerk.auth.signUp.continue` |
| Sign-up code field | `clerk.auth.signUp.code` |
| Legal consent, when shown | `clerk.auth.signUp.legalAccepted` |
| MFA setup choices | `clerk.auth.sessionTask.setupMfa.smsCode`, `clerk.auth.sessionTask.setupMfa.authenticatorApp` |

Prove the result from the host's state, not from the screen alone:

```ts
import { test, expect, CLERK_TEST_CODE } from '../../fixtures.ts';

test('signs in with an email code', { tags: ['form-entry'] }, async ({ host, screen }) => {
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
- Tag every spec that types a code `form-entry`. Those specs run by default. An agent runtime that refuses to type codes into an app that talks to hosted Clerk runs `bin/verify run --skip form-entry` and says so in the PR. CI runs the skipped specs.
- `bin/verify down` deletes every user the run created, including users created through the sign-up form, by their test email.

## Evidence

Every `run` writes `.verify/runs/<run-id>/` and prints its path:

| File | What it is |
| --- | --- |
| `run.json` | The sealed record: results per spec, git head, dirty flag, build key, device, identities, and any tainted files |
| `video.mp4` | `simctl io recordVideo` of the whole run |
| `screenshots/<label>.png` | Every `host.screenshot(label)` |
| `states.jsonl`, `state.json` | Every `VerifyState` the fixture read, and the last one |
| `app.log` | `com.clerk.verify` and `com.clerk.sdk` log lines from the run (network lines only with `debugLogs: true`) |
| `e2e/` | e2e's `report.json`, failure pages, and `screen.txt` for failed steps |
| `e2e.log` | e2e's console output |
| `specs/` | A copy of every spec the run used |

Proof standards: drive the real user path, capture the action and the resulting state (the video plus `states.jsonl`), and check side effects in `state.json` (`userId`, `orgId`, `pendingTasks`), not only the final screen.

After a run, sealing searches the run directory for every secret the run used (secret keys, tickets). A hit marks the file tainted in `run.json`, and a tainted run cannot be attached.

```console
$ bin/verify attach <run-id> --pr <n>                       # video and every screenshot
$ bin/verify attach <run-id> --pr <n> --screenshot profile  # video and one screenshot
```

`attach` posts once per run with `gh pr comment --attach`. It refuses a run that is tainted, failed, or shows a user id the run did not create.

## Cleanup

```console
$ bin/verify down --dry-run   # what it would release and delete
$ bin/verify down             # release the simulator, delete run users and their organizations, stop recorders
$ bin/verify down --stale     # also finish cleanup left by a crashed run in this worktree
```

`down` deletes only what this worktree created: its lane simulator and the users in its ledger (`~/.verify/ledgers/<worktree>.jsonl`). It never deletes `.verify/runs/`. Evidence survives teardown at `.claude/skills/verify/.verify/runs/<run-id>/`, and `down` lists the kept runs. Run `down` after a failed iteration too, so no simulator is stranded.

## Helpers

- `bin/verify` is the only helper. It is executable. Every invocation is shown above.
- `e2e.config.ts` composes the e2e config from the CLI's run context. `npx e2e list` works from this directory while a lease is held.
- `specs/fixtures.ts` is the `host` fixture.
- `features/` is the Feature Map. Start with `features/README.md`.

Keep the map honest with `/maintain-verification-skill`.
