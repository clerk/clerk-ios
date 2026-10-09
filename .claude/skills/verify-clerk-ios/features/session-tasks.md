# Session tasks

After sign-in, an instance can require more steps before the session becomes active. AuthView keeps the user on a session task screen until the task is done: set up MFA, or choose or create an organization.

## Sub-features

- `setup-mfa` stops a new session on the MFA setup screen and offers SMS and authenticator app.
- `complete-setup-mfa` enrolls an authenticator app, shows backup codes, and activates the session.
- `sign-up-setup-mfa` ends a sign-up on the MFA setup screen, with no second sign-in.
- `choose-organization` stops a new session on the organization task when the instance forces organization selection.

## How to get to it (user POV)

- Sign in on an instance that requires MFA. AuthView shows the MFA setup screen instead of closing.
- Sign up on an instance that requires MFA. AuthView shows the MFA setup screen after the password step.
- Sign in on an instance that forces organization selection. AuthView asks the user to create or choose an organization.

## Driving it with verify

Preconditions:

- `setup-mfa.settings.json`, `complete-setup-mfa.settings.json`, and `sign-up-setup-mfa.settings.json` require MFA at sign-up.
- `choose-organization.settings.json` forces organization selection. `.claude/skills/verify-clerk-ios/references/instances.md` describes a settings file.
- Each spec seeds a user and launches with a sign-in ticket for that user. The session stays pending, so the home shows `Signed out`, and the launch names that with `landsOn: host.app.signedOut`. The spec then taps `e2e.auth.signInFullScreen`, and AuthView adopts the pending session and shows the task. `sign-up-setup-mfa` seeds nobody. It gets an email from `host.newEmail()` and signs up through the form.

- **Setup MFA.** Run `e2e-tests/bin/control-clerk-ios run session-tasks/setup-mfa`. After the tap AuthView shows `clerk.auth.sessionTask.setupMfa.authenticatorApp`, and the spec expects `clerk.auth.sessionTask.setupMfa.smsCode` beside it. Screenshot `session-task`. It then taps the task view's UserButton, `clerk.userButton.profile`, and expects the seeded user's email in the account sheet. Screenshot `session-task-account`.
- **Complete MFA setup.** Run `e2e-tests/bin/control-clerk-ios run session-tasks/complete-setup-mfa`. It taps the authenticator app choice, reads `clerk.auth.sessionTask.totp.secret`, takes screenshot `totp-secret`, taps `clerk.auth.sessionTask.totp.continue`, fills `clerk.auth.sessionTask.totp.code` with the computed TOTP, taps `clerk.auth.sessionTask.backupCodes.continue`, and waits for the home to show `Signed in as` the seeded user's email with that user's ID. Screenshot `task-complete`.
- **Sign up into the task.** Run `e2e-tests/bin/control-clerk-ios run session-tasks/sign-up-setup-mfa`. It launches with `authMode: 'signUp'`, taps `e2e.auth.signInFullScreen`, signs up with that email, the test code, and a run password, and expects `clerk.auth.sessionTask.setupMfa.authenticatorApp` and `clerk.auth.sessionTask.setupMfa.smsCode` with no further step. Screenshot `sign-up-session-task`. It then taps the task view's UserButton and expects the new email in the account sheet. Screenshot `sign-up-session-task-account`.
- **Choose organization.** Run `e2e-tests/bin/control-clerk-ios run session-tasks/choose-organization`. After the tap AuthView shows the organization form field `clerk.organization.profileForm.name`. Screenshot `choose-organization-task`. The spec then taps the task view's UserButton and expects the seeded user's email in the account sheet.
- **Proof.** The screenshots show each task screen. The account sheet names the user whose session is pending.

## Gotchas

- A task view is the proof that the session is pending. AuthView shows one only for a pending session, and the home shows `Signed in as` only for an active one.
- The home treats a pending session as signed out and does not present the task by itself. Pass `landsOn: host.app.signedOut` to the launch, then open AuthView from the home.
- The organization task has no identifier of its own. It shows the same form as `Create organization` in the switcher. Above the form, the task also shows the line `Enter your organization details to continue`, which the switcher's form does not show. Only a task view has the UserButton in its toolbar.
- The TOTP code depends on the clock. A failure right at a 30 second boundary can be a clock edge, so rerun once before you debug.
