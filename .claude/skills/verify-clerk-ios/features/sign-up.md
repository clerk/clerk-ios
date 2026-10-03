# Sign up

A new user types a new email address into AuthView in sign-up mode, verifies it with a one-time code, sets a password, and ends up signed in.

## Sub-features

- `request-code` moves from the identifier field to the sign-up code screen for a new email.
- `complete` accepts the code, takes a password, and signs the new user in.

## How to get to it (user POV)

- Open AuthView in sign-up mode (`authMode: 'signUp'`), type a new email address, and tap Continue.
- Type the code, then a password, and tap Continue.

## Driving it with verify

Preconditions:

- `with-email-codes` allows sign-up with email code and requires a password.
- The spec reserves a fresh email with `host.newEmail('with-email-codes')`, so `.claude/skills/verify-clerk-ios/bin/control-clerk-ios down` can delete the user the form creates.

- **Request the code.** Run `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run sign-up/request-code`. The spec fills `clerk.auth.start.identifier`, taps `clerk.auth.start.continue`, expects `clerk.auth.signUp.code`, and waits for `signUpStatus` `missing_requirements`. Screenshot `signup-code`.
- **Complete sign-up.** Run `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run sign-up/complete`. `complete.e2e.ts` (tag `form-entry`) fills `clerk.auth.signUp.code` with `CLERK_TEST_CODE`, fills `clerk.auth.signUp.password` with `Verify-<runId>-Pw1!`, taps `clerk.auth.signUp.continue`, and waits for `signedIn` true and `sessionStatus` `active`. Screenshot `signed-up`.
- **Proof.** Both specs pass. `.claude/skills/verify-clerk-ios/bin/control-clerk-ios down` reports the sign-up user as deleted. When only `request-code` ran, `down` reporting 0 users is correct: a sign-up that stops at the code screen never creates a user. With `--skip form-entry`, the proof is `request-code` passing with screenshot `signup-code`, and `complete` reported as `skipped by --skip form-entry`. Run `complete` alone with `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run sign-up/complete`.

## Gotchas

- Sign-up mode still uses the start screen's `clerk.auth.start.identifier` field for the email.
- Use `host.tap` and `host.fill` inside AuthView. Plain locator actions refuse there because of the iOS 27 `Toolbar` node.
- A user created through the form exists only by email until `down` resolves it. Always reserve the email with `host.newEmail` so cleanup finds it.
- `complete.e2e.ts` is tagged `form-entry`.
