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

- The standard settings allow sign-up with an email code and require a password.
- The spec reserves a fresh email with `host.newEmail()`, so the run records the user the form creates.

- **Request the code.** Run `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run sign-up/request-code`. The spec fills `clerk.auth.start.identifier`, taps `clerk.auth.start.continue`, expects `clerk.auth.signUp.code`, and waits for `signUpStatus` `missing_requirements`. Screenshot `signup-code`.
- **Complete sign-up.** Run `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run sign-up/complete`. `complete.e2e.ts` (tag `form-entry`) fills `clerk.auth.signUp.code` with `CLERK_TEST_CODE`, waits for `clerk.auth.signUp.password`, fills the one text box on the screen with `Verify-<runId>-Pw1!`, taps `clerk.auth.signUp.continue`, and waits for `signedIn` true and `sessionStatus` `active`. Screenshots `signup-code` and `signed-up`.
- **Proof.** Both specs pass. `run.json` lists the reserved email under `identities` with the id of the user the form created, and `.claude/skills/verify-clerk-ios/bin/control-clerk-ios down` deletes that user with the application. When only `request-code` ran, the email has a `null` `userId`, because a sign-up that stops at the code screen never creates a user. With `--skip form-entry`, the proof is `request-code` passing with screenshot `signup-code`, and `complete` reported as `skipped by --skip form-entry`. Run `complete` alone with `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run sign-up/complete`.

## Gotchas

- Sign-up mode still uses the start screen's `clerk.auth.start.identifier` field for the email.
- Use `host.tap` and `host.fill` inside AuthView. Plain locator actions refuse there because of the iOS 27 `Toolbar` node.
- Always reserve the email with `host.newEmail`. The run finds the user that the form created by that email, and `attach` refuses a run that shows a user it cannot account for.
- `clerk.auth.signUp.password` matches three nodes once the field has focus: the floating label, the secure field, and the reveal button. Wait on `.first()`, then wait for `screen.getByRole('textbox')` to have a count of 1 before filling it. Two text boxes match for a moment while the code screen is replaced.
- After a password is submitted, iOS may cover the app with its own "Save Password?" sheet. `host.waitForState` taps "Not Now" when it cannot read the state element and that sheet is up.
- `complete.e2e.ts` is tagged `form-entry`.
