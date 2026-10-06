# Session tasks

After sign-in, an instance can require more steps before the session becomes active. AuthView keeps the user on a session task screen until the task is done: set up MFA, or choose or create an organization.

## Sub-features

- `setup-mfa` stops a new session on the MFA setup screen and offers SMS and authenticator app.
- `complete-setup-mfa` enrolls an authenticator app, shows backup codes, and activates the session.
- `choose-organization` stops a new session on the organization task when the instance forces organization selection.

## How to get to it (user POV)

- Sign in on an instance that requires MFA. AuthView shows the MFA setup screen instead of closing.
- Sign in on an instance that forces organization selection. AuthView asks the user to create or choose an organization.

## Driving it with verify

Preconditions:

- `setup-mfa.e2e.ts` and `complete-setup-mfa.e2e.ts` declare `config: { auth_multi_factor: { required_for_sign_up: true } }` and `environment: { 'user_settings.sign_up.mfa.required': true }`.
- `choose-organization.e2e.ts` declares `config: { organization_settings: { force_organization_selection: true } }` and `environment: { 'organization_settings.force_organization_selection': true }`.
- `run` puts the worktree's application on the declared settings before the tests in each file start. `references/instances.md` describes the declaration.
- Each spec seeds a user and launches `screen: 'auth'` with a sign-in ticket for that user, so AuthView adopts the pending session.

- **Both task screens at once.** Run `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run session-tasks --skip form-entry` to run `setup-mfa` and `choose-organization` and skip `complete-setup-mfa`. The run has one group per declaration, so it writes `e2e/` and `e2e-2/`.
- **Setup MFA.** Run `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run session-tasks/setup-mfa`. The spec expects `ticket` `succeeded`, `sessionStatus` `pending`, `pendingTasks` containing `setup-mfa`, and both `clerk.auth.sessionTask.setupMfa.authenticatorApp` and `clerk.auth.sessionTask.setupMfa.smsCode`. Screenshot `session-task`.
- **Complete MFA setup.** Run `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run session-tasks/complete-setup-mfa` (tag `form-entry`). It taps the authenticator app choice, reads `clerk.auth.sessionTask.totp.secret`, takes screenshot `totp-secret`, taps `clerk.auth.sessionTask.totp.continue`, fills `clerk.auth.sessionTask.totp.code` with the computed TOTP, taps `clerk.auth.sessionTask.backupCodes.continue`, and waits for `sessionStatus` `active` with no pending tasks.
- **Choose organization.** Run `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run session-tasks/choose-organization`. The spec expects `pendingTasks` containing `choose-organization` and the organization form field `clerk.organization.profileForm.name`. Screenshot `choose-organization-task`.
- **Proof.** `states.jsonl` lists the pending task for each test, and the screenshot shows the task screen. `state.json` holds only the run's last state.

## Gotchas

- `signedIn` is true for a pending session. Read `sessionStatus` to tell pending from active.
- Launch with `screen: 'auth'`. The home screen shows the pending session but does not present the task screen without a tap on UserButton.
- The TOTP code depends on the clock. A failure right at a 30 second boundary can be a clock edge, so rerun once before you debug.
- `complete-setup-mfa.e2e.ts` is tagged `form-entry`.
- Task screens live inside AuthView, so use `host.tap` and `host.fill` there.
