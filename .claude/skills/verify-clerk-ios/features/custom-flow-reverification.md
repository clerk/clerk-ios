# Custom reverification flow

An app that builds its own reverification screen on the SDK's API reverifies a signed-in user with a reset password code instead of their password, and the same step sets a new password. This is the way out for a user whose password was found in a data breach, which makes `Session.verifyWithPassword(_:)` fail with `form_password_pwned`. ClerkKitUI has no reverification view, so E2EHost has a small form of its own for this, `CustomReverifyView`.

## Sub-features

- `reset-password-code` starts a first-factor reverification, sends a reset password code to the user's email, verifies it with a new password, returns to the home, and then signs in through AuthView with the new password. Its second test shows that a wrong code leaves the form on screen with Clerk's error.

## How to get to it (user POV)

- Launch the app signed in and tap `Custom reverification` on the home. The screen has `Send reset code`, then an email code field, a new password field, and `Verify and set password`.

## Driving it with verify

Preconditions:

- The standard settings have email and password on, so reverification offers the `reset_password_email_code` factor. The server offers it only to a user who has a password, so the spec seeds its user with `host.seedUser({ password: true })`.
- The new password is `runPassword(host.runId)`, which differs from the password the user was seeded with.

- **Send the code.** Run `e2e-tests/bin/control-clerk-ios run custom-flow-reverification/reset-password-code`. The test launches signed in with a ticket and taps `e2e.home.customReverify`. It taps `verify.customReverify.sendCode`, which calls `Session.startVerification(level: .firstFactor)`, takes the `emailAddressId` of the `resetPasswordEmailCode` factor in `supportedFirstFactors`, and calls `Session.sendResetPasswordEmailCode(emailAddressId:)`. It expects `verify.customReverify.code` with no `verify.customReverify.error`. Screenshot `reverify-code`.
- **Verify and set the new password.** The test fills `verify.customReverify.code` with `CLERK_TEST_CODE` and `verify.customReverify.newPassword` with the new password, then taps `verify.customReverify.verifyCode`, which calls `Session.verifyWithResetPasswordEmailCode(code:newPassword:)`. The form returns to the home only when that call returns a `complete` verification, so `host.expectSignedInAs(user)` proves it. Screenshot `reverified`.
- **Sign in with the new password.** The test taps `Sign out`, opens the AuthView sheet, fills `clerk.auth.start.identifier` with the user's email, taps `clerk.auth.start.continue`, waits for `clerk.auth.signIn.password`, fills it with the new password, taps `clerk.auth.signIn.continue`, and expects the home to show the user again. That sign-in succeeds only if the reverification changed the password. Screenshot `signed-in-with-new-password`.
- **Wrong code.** The second test sends the code, fills `000000` and a new password, taps `verify.customReverify.verifyCode`, and expects `verify.customReverify.error` to read `Incorrect code` with `verify.customReverify.code` still on screen. Screenshot `reverify-wrong-code`.
- **Proof.** Both tests pass.

## Gotchas

- A first-factor reverification started right after a ticket sign-in still needs a factor: the server starts each new reverification with no verified factor unless an earlier one in the same session already verified one. So `Send reset code` always leads to the code step.
- The new password field sets no content type, like the SDK's password fields in E2E mode (`ClerkE2EEnvironment`). With a password content type, iOS covers the field with its strong password suggestion, which swallows text typed by UI automation.
- XCTest screenshots blank secure fields, so the new password field shows as a black box in `reverify-code`.
- A reverification error, such as a wrong code or a rejected password, shows in `verify.customReverify.error`, and the form stays on screen. `Incorrect code` is Clerk's message for a wrong code. It comes from the API, so a change of that wording fails the second test. A wrong code also counts toward the code's attempt limit.
- `Custom reverification` sits with `Organization tabs`, so the home inside the organization tabs does not show it.
- The screen keeps no state across launches. Every launch starts on the home.
