# clerk-ios verification map

This directory is the maintained source for verifying the user-facing behavior of the clerk-ios SDK UI (ClerkKitUI) through the E2EHost example app. Read this index before driving the app, then use the matching feature file as the recipe. Every recipe runs through the `verify` CLI and golden specs under `specs/golden/<feature>/`.

## Baseline preconditions

- Run every command from the root of a clerk-ios worktree. The CLI is `.claude/skills/verify-clerk-ios/bin/control-clerk-ios`, or `control-clerk-ios` with that `bin` directory on `PATH`.
- Run `npm ci --prefix .claude/skills/verify-clerk-ios` once.
- Then run `.claude/skills/verify-clerk-ios/bin/control-clerk-ios doctor`. Its first line names the backend, `local` or `remote`, and why. It exits 3 until a build matches the current tree; on a clean Mac `build` is the only failing check until the first `.claude/skills/verify-clerk-ios/bin/control-clerk-ios up`. On Linux, `remote-commit` also fails until HEAD is pushed, and `gh-attach` fails without `gh`.
- Specs run on the standard test instance, in one Clerk application that `up` creates for this worktree and `down` deletes. A spec names no instance, and a spec file that needs other settings declares them. `SKILL.md` under Test instances has the declaration, the Platform API key the CLI needs, and the override that uses the standing instances from `.keys.json` or `CLERK_TEST_KEYS_JSON`. Never print a key.
- On a Mac the CLI drives only its own lane simulator, `verify-ios-<n>`, cloned from `Clerk Verify Template iOS`. Never drive `iPhone Air`, the template, a physical device, or a simulator another worktree holds.
- On Linux the CLI drives a remote simulator on a CI runner instead, and every recipe here is unchanged. The differences are in `SKILL.md` under Remote simulator: commit and push before `up` or `run`, because the session builds the pushed commit, and run `down` as soon as you are done, because the session is billed by the minute.
- Every launch gets a new `verifyStorageScope`, so no spec inherits a session from another spec.

### Test users and sign-in

- **Emails.** Any address that contains `+clerk_test@` is a test address. Clerk sends no mail and accepts the code below. The fixture mints `verify_<runId>_<n>+clerk_test@example.com` per run with `host.newEmail()` or `host.seedUser()`.
- **Phones.** US numbers 555-0100 to 555-0199 are test numbers, typed as ten digits such as `5555550142`. On the standing instances they are shared across repos, CI, and agents, so get one from `host.seedUser({ phone: true })` instead of picking one by hand.
- **One-time code.** `424242` verifies every email and SMS code for test addresses and phones. Specs use the constant `CLERK_TEST_CODE`. It is public and not an e2e secret, so screenshots after the fill are kept.
- **Passwords.** The standard instance requires a password at sign-up. Use a throwaway per run, such as `Verify-<runId>-Pw1!`.
- **Authenticator codes.** Read the setup key from `clerk.auth.sessionTask.totp.secret` and compute the 6-digit RFC 6238 code (SHA-1, 30 second step). `specs/golden/session-tasks/complete-setup-mfa.e2e.ts` has the helper.

The standard instance has every auth method and every signed-in feature. A spec file that needs other settings declares them, as `SKILL.md` under Test instances describes.

| Step | SDK identifier |
| --- | --- |
| Identifier field (email or username) | `clerk.auth.start.identifier` |
| Switch between email and phone | `clerk.auth.start.identifierSwitcher` |
| Phone field | `clerk.auth.start.phoneNumber` |
| Continue on the start screen | `clerk.auth.start.continue` |
| Sign-in code field | `clerk.auth.signIn.code` |
| Sign-in password field | `clerk.auth.signIn.password` |
| Try another method on a code or password screen | `clerk.auth.signIn.useAnotherMethod` |
| Try another method on the email link screen, which has no identifier | `screen.getByRole('button', { name: 'Use another method' })` |
| Pick a method from the list | `clerk.auth.signIn.alternativeMethod.<strategy>`, for example `clerk.auth.signIn.alternativeMethod.email_code` |
| Sign-up email, password, continue | `clerk.auth.signUp.emailAddress`, `clerk.auth.signUp.password`, `clerk.auth.signUp.continue` |
| Sign-up code field | `clerk.auth.signUp.code` |
| Legal consent, when shown | `clerk.auth.signUp.legalAccepted` |
| MFA setup choices | `clerk.auth.sessionTask.setupMfa.smsCode`, `clerk.auth.sessionTask.setupMfa.authenticatorApp` |

The source of truth for these names is `Sources/ClerkKitUI/Components/Auth/ClerkAccessibilityIdentifiers.swift`. Keep this table in sync with it.

Rules:

- Type only `+clerk_test` emails, 555-0100 to 0199 phones, and `424242`. The repo is public and every video can land on a PR.
- Use ticket sign-in (`host.launch({ signedInAs })`) only to reach signed-in screens for features that are not about authentication. A change to an auth method gets a spec that drives the real form.
- Tag every spec that types a code `form-entry`. Those specs run by default. A runtime that refuses to type codes into an app that talks to hosted Clerk runs `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run --skip form-entry` and says so in the PR.
- `.claude/skills/verify-clerk-ios/bin/control-clerk-ios down` deletes this worktree's application, and with it every user the run created, including users created through the sign-up form.

## Driving conventions

- Input only goes through specs. To look at any state past launch, write a spec, `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run` it, then `.claude/skills/verify-clerk-ios/bin/control-clerk-ios screen`.
- Prefer SDK identifiers (`screen.getByTestId('clerk....')`) and the E2EHost ids `e2e.auth.signIn`, `verify.signOut`, `verify.userId`, `verify.state`. Fall back to visible text only where the SDK has no identifier.
- Inside AuthView, the profile, and organization sheets, act with `host.tap(locator)` and `host.fill(locator, text)`. On iOS 27 a SwiftUI toolbar adds a hittable full-screen `Toolbar` node, and agent-device 0.21.18 refuses `locator.tap()` and `locator.fill()` on anything under it with "covered by another visible element".
- Prove results from `verify.state` (`host.launch`, `host.state`, `host.waitForState`), not from the screen alone. Every spec keeps at least one exact assertion on `verify.state` or an SDK identifier.
- `verifyScreen` routes the host: `home`, `auth`, `userProfile`, `orgSwitcher`, `orgList`, `orgProfile`. `state.screen` reports what is on screen: `launching` during a ticket sign-in, `error` for a rejected key, and `home` once an `auth` launch completes.

## Proof and skip reporting

- A proof is a passing `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run` whose run directory holds `video.mp4`, `screenshots/`, `states.jsonl`, `state.json`, `app.log`, and `e2e/report.json`.
- Name the run id and the specs in the PR. Attach with `.claude/skills/verify-clerk-ios/bin/control-clerk-ios attach <run-id> --pr <n>`.
- Report a skipped `form-entry` spec as skipped with the reason. The CLI prints `skipped by --skip form-entry`. Never report it as verified through a ticket launch.
- A runtime that skips form entry proves each auth flow up to its code screen with the `request-code` spec, and reports the `complete` spec as skipped.
- Report an unreachable path with the attempted command and the unmet precondition.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph describing the user-visible behavior, then exactly four H2 sections in this order: `Sub-features`, `How to get to it (user POV)`, `Driving it with verify`, and `Gotchas`. `Driving it with verify` starts with `Preconditions:` and names the golden specs that prove each sub-feature.

## Features

- [Auth start](./auth-start.md) covers opening AuthView from the home button and from a direct launch.
- [Sign in with an email code](./sign-in-email-code.md) covers requesting and entering the email code.
- [Sign up](./sign-up.md) covers requesting the sign-up code and completing sign-up with a password.
- [User button and profile](./user-button-and-profile.md) covers UserButton, UserProfileView, and sign-out.
- [Session tasks](./session-tasks.md) covers the setup-MFA and choose-organization tasks after sign-in. The ticket-seeded setup-MFA spec is `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run session-tasks/setup-mfa`.
- [Organizations](./organizations.md) covers creating an organization from OrganizationSwitcher.

Not mapped yet: phone code sign-in, password sign-in, social providers (no real OAuth on simulators), passkeys and biometrics (no associated domains or Secure Enclave on the simulator).
