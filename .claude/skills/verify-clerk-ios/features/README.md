# clerk-ios verification map

This directory is the maintained source for verifying the user-facing behavior of the clerk-ios SDK UI (ClerkKitUI) through the E2EHost example app. Read this index before driving the app, then use the matching feature file as the recipe. Every recipe runs through the `control-clerk-ios` CLI and the golden specs under `specs/golden/<feature>/`.

## Baseline preconditions

- Run every command from the root of a clerk-ios worktree. The CLI is `.claude/skills/verify-clerk-ios/bin/control-clerk-ios`.
- Run `npm ci --prefix .claude/skills/verify-clerk-ios` once per worktree.
- Run `.claude/skills/verify-clerk-ios/bin/control-clerk-ios doctor`. After the once-per-machine setup in `SKILL.md` under Launch, `build` is the only failing check until the first `up` or `run`.
- Specs run in one Clerk application that `up` creates for this worktree and `down` deletes. Its development instance is on the standard settings, which have every auth method and signed-in feature that these recipes use. A spec file that needs other settings declares them, as `references/instances.md` describes.
- The CLI drives only its own lane simulator, `verify-ios-<n>`. Never drive any other simulator, the template, a physical device, or a lane another worktree holds.
- Every launch gets a new `verifyStorageScope`, so no spec inherits a session from another spec.

### Test users and sign-in

Clerk's test mode makes these identities safe to type into the real app.

| Identity | What to use |
| --- | --- |
| Email | Any address that contains `+clerk_test@`. Clerk sends no mail to it and accepts the code below. `host.seedUser()` and `host.newEmail()` mint `verify_<runId>_<n>+clerk_test@example.com`, new for each run |
| Phone | A US number from 555-0100 to 555-0199, typed as ten digits such as `2015550142`. Get one from `host.seedUser({ phone: true })` instead of picking one by hand |
| One-time code | `424242` verifies every email code and SMS code for a test address or number. Specs use the constant `CLERK_TEST_CODE`. The code is public, so screenshots after the fill are kept |
| Password | The standard settings require a password at sign-up. Use a throwaway one per run, such as `Verify-<runId>-Pw1!` |
| Authenticator code | Read the setup key from `clerk.auth.sessionTask.totp.secret` and compute the 6-digit RFC 6238 code (SHA-1, 30-second step). `specs/golden/session-tasks/complete-setup-mfa.e2e.ts` has a helper |

A change that touches sign-in or sign-up gets a spec that drives the real form with one of these identities. Any other spec signs in with a ticket, `host.launch({ signedInAs: user })`, which is the intended shortcut.

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

The source of truth for these names is `Sources/ClerkKitUI/Components/Auth/ClerkAccessibilityIdentifiers.swift`. Keep this table in sync with it. The identifiers are internal test hooks, not public API, and they can change.

On the standard settings an email sign-in starts on the email-link screen, so a spec switches to the email code through `Use another method`. Sign-up mode uses the start screen's `clerk.auth.start.identifier` field for the email.

These rules hold for every spec.

- Type only `+clerk_test` emails, 555-0100 to 555-0199 phone numbers, and `424242`. Never type a real person's address, number, or password. The repository is public, and every video can land on a PR.
- Tag every spec that types a code `form-entry`. Those specs run by default. A runtime that cannot type codes into the app runs `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run --all --skip form-entry` and says so in the PR.
- `.claude/skills/verify-clerk-ios/bin/control-clerk-ios down` deletes this worktree's application, and with it every user a run created, including users created through the sign-up form.

## Driving conventions

- Input reaches the app only through specs. To look at any state past launch, write a spec, `run` it, then run `screen`.
- Prefer SDK identifiers (`screen.getByTestId('clerk....')`) and the E2EHost ids `e2e.auth.signIn`, `verify.signOut`, `verify.userId`, and `verify.state`. Fall back to visible text only where the SDK has no identifier.
- Fill every SDK text field with `host.fill(locator, text)`, which taps the field and types into it. An SDK text field shows no text input until it has focus, and until then its identifier is on the floating label, so a plain `locator.fill()` on an email or name field fails with "no text input found at the provided coordinates to clear". A tap needs no helper: `host.tap(locator)` is `locator.tap()` with the assertion timeout. `host.fill` reads the focused input back and types once more if it is still empty. It cannot read a secure field, so it types a password once.
- Prove results from `verify.state` (`host.launch`, `host.state`, `host.waitForState`), not from the screen alone. Every spec keeps at least one exact assertion on `verify.state` or an SDK identifier.
- `verifyScreen` routes the host: `home`, `auth`, `userProfile`, `orgSwitcher`, `orgList`, `orgProfile`. `state.screen` reports what is on screen: `launching` during a ticket sign-in, `error` for a missing or malformed publishable key, and `home` once an `auth` launch completes.

## Proof and skip reporting

- A proof is a passing `run` whose run directory holds `video.mp4`, `screenshots/`, `states.jsonl`, `state.json`, `app.log`, and `e2e/report.json`.
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
- [Session tasks](./session-tasks.md) covers the setup-MFA and choose-organization tasks after sign-in.
- [Organizations](./organizations.md) covers creating an organization from OrganizationSwitcher.

Not mapped yet: phone code sign-in, password sign-in, social providers (no real OAuth on simulators), passkeys and biometrics (no associated domains or Secure Enclave on the simulator).
