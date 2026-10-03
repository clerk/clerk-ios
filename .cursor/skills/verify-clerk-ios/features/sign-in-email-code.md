# Sign in with an email code

An existing user types their email address into AuthView, receives a one-time code, types it, and ends up signed in with an active session.

## Sub-features

- `request-code` moves from the identifier field to the code screen for an existing user.
- `complete` accepts the code and signs the user in.

## How to get to it (user POV)

- Open AuthView in sign-in mode, type the email address, and tap Continue.
- On `with-email-codes` the first factor is an email link ("Check your email", "Open email app"). Tap `Use another method`, then `Email code`.
- Type the code from the email into the code field.

## Driving it with verify

Preconditions:

- `with-email-codes` has the `email_code` strategy on. `bin/verify doctor` checks it.
- The spec seeds its own `+clerk_test` user through `host.seedUser`. Do not reuse a user from another run.

- **Both, in a runtime that can't type codes.** Run `bin/verify run sign-in-email-code --skip form-entry`. It runs `request-code` and reports `complete` as skipped.
- **Request the code.** Run `bin/verify run sign-in-email-code/request-code`. The spec fills `clerk.auth.start.identifier` with the seeded email, taps `clerk.auth.start.continue`, waits for `signInStatus` `needs_first_factor`, taps `Use another method` and `clerk.auth.signIn.alternativeMethod.email_code`, and expects `clerk.auth.signIn.code` and the email text. Screenshot `code-screen`.
- **Enter the code.** Run `bin/verify run sign-in-email-code/complete`. `complete.e2e.ts` (tag `form-entry`) fills `clerk.auth.signIn.code` with `CLERK_TEST_CODE` and waits for `signedIn` true, `sessionStatus` `active`, and `userId` equal to the seeded user's id. Screenshots `code-screen-before-fill` and `signed-in`, so a full run keeps `request-code`'s `code-screen` too.
- **Proof.** Both specs pass in one run. A runtime that must use `--skip form-entry` proves `request-code` only and reports `complete` as skipped. Run `complete` alone with `bin/verify run sign-in-email-code/complete`.

## Gotchas

- `complete.e2e.ts` is tagged `form-entry`. `bin/verify run --skip form-entry` skips it. CI and other runtimes run it.
- The screenshot before the code fill shows the code screen. Keep it, because it is the evidence a skipping runtime can still produce.
- The test code works only for `+clerk_test` emails. Any other address sends a real email.
- The email-link screen has no code field. A spec that expects `clerk.auth.signIn.code` right after Continue times out with match count 0.
- AuthView controls sit under an iOS 27 `Toolbar` node that agent-device treats as covering them. Use `host.tap` and `host.fill`, not `locator.tap()` and `locator.fill()`.
