# Sign in with an email code

An existing user types their email address into AuthView, receives a one-time code, types it, and ends up signed in with an active session.

## Sub-features

- `request-code` moves from the identifier field to the code screen for an existing user.
- `complete` accepts the code and signs the user in.

## How to get to it (user POV)

- Open AuthView in sign-in mode, type the email address, and tap Continue.
- On the standard settings the first factor is an email link ("Check your email", "Open email app"). Tap `Use another method`, then `Email code`.
- Type the code from the email into the code field.

## Driving it with verify

Preconditions:

- The standard settings have the `email_code` strategy on. The `settings` check of `.claude/skills/verify-clerk-ios/bin/control-clerk-ios doctor` compares the live instance with the standard file once the worktree holds an application.
- The spec seeds its own `+clerk_test` user through `host.seedUser`. Do not reuse a user from another run.

- **Both, in a runtime that can't type codes.** Run `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run sign-in-email-code --skip form-entry`. It runs `request-code` and reports `complete` as skipped.
- **Request the code.** Run `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run sign-in-email-code/request-code`. The spec fills `clerk.auth.start.identifier` with the seeded email, taps `clerk.auth.start.continue`, waits for `signInStatus` `needs_first_factor`, taps `Use another method` and `clerk.auth.signIn.alternativeMethod.email_code`, and expects `clerk.auth.signIn.code` and the email text. Screenshot `code-screen`.
- **Enter the code.** Run `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run sign-in-email-code/complete`. `complete.e2e.ts` (tag `form-entry`) fills `clerk.auth.signIn.code` with `CLERK_TEST_CODE` and waits for `signedIn` true, `sessionStatus` `active`, and `userId` equal to the seeded user's id. Screenshots `code-screen-before-fill` and `signed-in`, so a full run keeps `request-code`'s `code-screen` too.
- **Proof.** Both specs pass in one run. A runtime that must use `--skip form-entry` proves `request-code` only and reports `complete` as skipped. Run `complete` alone with `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run sign-in-email-code/complete`.

## Gotchas

- `complete.e2e.ts` is tagged `form-entry`. `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run sign-in-email-code --skip form-entry` skips it. A runtime that can type codes runs it.
- The screenshot before the code fill shows the code screen. Keep it, because it is the evidence a skipping runtime can still produce.
- The test code works only for `+clerk_test` emails. Any other address sends a real email.
- The email-link screen has no code field. A spec that expects `clerk.auth.signIn.code` right after Continue times out with match count 0.
- Fill AuthView fields with `host.fill`, not `locator.fill()`. A field shows no text input until it has focus, and a plain fill fails with "no text input found at the provided coordinates to clear".
