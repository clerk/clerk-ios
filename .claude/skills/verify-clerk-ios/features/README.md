# clerk-ios verification map

This directory is the maintained source for verifying the user-facing behavior of the clerk-ios SDK UI (ClerkKitUI) through the E2EHost example app. Read this index before driving the app, then use the matching feature file as the recipe. Every recipe runs through the `control-clerk-ios` CLI and the specs under `specs/features/<feature>/`.

## Baseline preconditions

`.claude/skills/verify-clerk-ios/SKILL.md` under Launch has the setup and the commands. These facts hold for every recipe here.

- The standard settings have every auth method and signed-in feature that these recipes use. The `settings` check of `doctor` compares the live instance with the standard file once the worktree holds an application.
- Every launch gets a new `verifyStorageScope`, so no spec inherits a session from another spec. A launch with `keepStorage: true` reuses the scope of the launch before it in the same test.
- `down` deletes this worktree's application, and with it every user and organization a run created, including users created through the sign-up form.
- The screen tree leaves out what a sheet covers, so the home is readable only after the sheet has closed.

### Test users and sign-in

Clerk's test mode makes these identities safe to type into the real app.

| Identity | What to use |
| --- | --- |
| Email | Any address that contains `+clerk_test@`. Clerk sends no mail to it and accepts the code below. `host.seedUser()` and `host.newEmail()` mint an address such as `maya.7c1e+clerk_test@example.com`, a first name and the run tag, new for each test of the run |
| Phone | A US number from 555-0100 to 555-0199, typed as ten digits such as `2015550142`. Get one from `host.seedUser({ phone: true })`, or from `host.newPhone()` for a sign-up, instead of picking one by hand. Both give `+1` and the ten digits |
| One-time code | `424242` verifies every email code and SMS code for a test address or number. Specs use the constant `CLERK_TEST_CODE` |
| Password | The standard settings require a password at sign-up. Fill it with `runPassword(host.runId)` from `specs/support/clerk.ts`, such as `Otter-Lamp-3917`. For a password sign-in, seed the user with `host.seedUser({ password: true })` and fill the field with `host.fill(field, user.password!)` |
| Authenticator code | Read the setup key from `clerk.auth.sessionTask.totp.secret` and compute the 6-digit RFC 6238 code (SHA-1, 30-second step). `totp` in `specs/totp.ts` computes it |

| Step | SDK identifier |
| --- | --- |
| Identifier field (email or username) | `clerk.auth.start.identifier` |
| Switch between email and phone | `clerk.auth.start.identifierSwitcher` |
| Phone field | `clerk.auth.start.phoneNumber` |
| Continue on the start screen | `clerk.auth.start.continue` |
| Sign-in code field | `clerk.auth.signIn.code` |
| Sign-in password field | `clerk.auth.signIn.password` |
| Try another method on a code or password screen | `clerk.auth.signIn.useAnotherMethod` |
| Try another method on the email link screen, which has no identifier and is off on the standard settings | `screen.getByRole('button', { name: 'Use another method' })` |
| Pick a method from the list | `clerk.auth.signIn.alternativeMethod.<strategy>`, for example `clerk.auth.signIn.alternativeMethod.email_code` |
| Sign-up email, password, continue | `clerk.auth.signUp.emailAddress`, `clerk.auth.signUp.password`, `clerk.auth.signUp.continue` |
| Sign-up code field | `clerk.auth.signUp.code` |
| Legal consent, when shown | `clerk.auth.signUp.legalAccepted` |
| MFA setup choices | `clerk.auth.sessionTask.setupMfa.smsCode`, `clerk.auth.sessionTask.setupMfa.authenticatorApp` |

The source of truth for these names is `Sources/ClerkKitUI/Components/Auth/ClerkAccessibilityIdentifiers.swift`. Keep this table in sync with it. The identifiers are internal test hooks, not public API, and they can change.

On the standard settings an email sign-in for a user with no password goes straight to the email code screen. The email link is off there. Sign-up mode uses the start screen's `clerk.auth.start.identifier` field for the email.

## Driving conventions

- Input reaches the app only through specs. To look at any screen past launch, write a spec, `run` it, then run `screen`.
- Prefer SDK identifiers (`screen.getByTestId('clerk....')`) and the locators of the home in `host.app`. Fall back to visible text only where the SDK has no identifier.

## Proof

- A proof is a passing `run` whose run directory holds `video.mp4`, `screenshots/`, `app.log`, and `e2e/report.json`.
- Name the run id and the specs in the PR. Attach with `e2e-tests/bin/control-clerk-ios attach <run-id> --pr <n>` and `--screenshot <label>` for a still change or `--video` for behavior or a flow, with the part that shows the change inside `host.evidence`. Add `--before <run-id>` when the change is to something that exists. `SKILL.md` has the choice under Evidence.
- Report an unreachable path with the attempted command and the unmet precondition.

## Feature entry contract

Each feature file starts with an H1 title and one paragraph describing the user-visible behavior, then four H2 sections in this order: `Sub-features`, `How to get to it (user POV)`, `Driving it with verify`, and `Gotchas`. `Driving it with verify` starts with `Preconditions:` and names the specs that prove each sub-feature. A feature with states that no spec can reach has a `States a spec cannot reach` section before `Gotchas`, which names each state, where the app decides it, and what it takes.

## Features

- [Auth start](./auth-start.md) covers opening AuthView from the home in a sheet and full screen, dismissing it, and opening it with an initial identifier.
- [Sign in with an email code](./sign-in-email-code.md) covers requesting and entering the email code.
- [Sign in with an SMS code](./sign-in-phone-code.md) covers requesting and entering the SMS code from the AuthView sheet the home opens.
- [Custom sign-in flow](./custom-flow-sign-in.md) covers E2EHost's own form on `clerk.auth.signInWithPhoneCode(phoneNumber:)`.
- [Sign up](./sign-up.md) covers requesting the sign-up code, completing sign-up with a password, and signing up with a phone number.
- [Session persistence](./session-persistence.md) covers a session that survives a restart of the app.
- [User button and profile](./user-button-and-profile.md) covers UserButton, UserProfileView, its Manage account and Security screens, sign-out, and deleting the account.
- [Session tasks](./session-tasks.md) covers the setup-MFA and choose-organization tasks after sign-in, the setup-MFA task after sign-up, and finishing the setup-MFA task with an authenticator code.
- [Organizations](./organizations.md) covers creating an organization from OrganizationSwitcher.
- [Organization profile](./organization-profile.md) covers the profile that `Manage` opens from OrganizationSwitcher: its rows, the Members tabs and search, sending an invitation, verified domains, renaming, and leaving or deleting the organization. It covers a member who can read domains but not manage them, and a request to join on the Requests tab, with organizations that specs seed, and it lists the states no spec reaches.

Not mapped yet: password sign-in, the email link (off on the standard settings), the profile's own flows past its first screens (editing the profile, adding an email address or a phone number, changing the password, adding a second factor, and switching between signed-in accounts), completing the setup-MFA task with an SMS code, the reset-password session task, the choose-organization task's list of memberships, invitations, and suggestions, organization invitations in the switcher (the harness cannot seed them; the Requests test in [Organization profile](./organization-profile.md) covers a suggestion), social providers (no real OAuth on simulators), and passkeys and biometrics (no associated domains or Secure Enclave on the simulator).
