# Sign in with an email code

An existing user types their email address into AuthView, receives a one-time code, types it, and ends up signed in with an active session.

## Sub-features

- `complete` accepts the code and signs the user in.

## How to get to it (user POV)

- Open AuthView in sign-in mode, type the email address, and tap Continue.
- On the standard settings the first factor is an email link ("Check your email", "Open email app"). Tap `Use another method`, then the row that reads `Email code to <address>`.
- Type the code from the email into the code field.

## Driving it with verify

Preconditions:

- The standard settings have the `email_code` strategy on.
- The spec seeds its own `+clerk_test` user through `host.seedUser`.

- **Request the code.** Run `e2e-tests/bin/control-clerk-ios run sign-in-email-code/complete`. The spec launches with `authMode: 'signIn'`, taps `e2e.auth.signInFullScreen` on the home, fills `clerk.auth.start.identifier` with the seeded email, taps `clerk.auth.start.continue`, waits for the `Use another method` button, taps it and `clerk.auth.signIn.alternativeMethod.email_code`, and expects `clerk.auth.signIn.code` and the email text. Screenshot `code-screen-before-fill`.
- **Enter the code.** The spec then fills `clerk.auth.signIn.code` with `CLERK_TEST_CODE` and waits for the home to show `Signed in as` the seeded user's email with that user's ID. Screenshot `signed-in`.
- **Proof.** The spec passes.

## Gotchas

- The test code works only for `+clerk_test` emails. Any other address sends a real email.
- The email-link screen has no code field. A spec that expects `clerk.auth.signIn.code` right after Continue times out with match count 0.
