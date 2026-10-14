# Custom sign-in flow

An app that builds its own sign-in screen on the SDK's API sends an SMS code to an existing user and signs them in with it. No prebuilt view is involved, so E2EHost has a small form of its own for this, `CustomSignInView`.

## Sub-features

- `request-code` shows Clerk's error for a number no user holds.
- `complete` sends the SMS code, shows the code field, verifies the code, and returns to the home, which shows the user and the session.

## How to get to it (user POV)

- Launch the app signed out and tap `Custom sign-in`. The screen has a phone field and `Send code`, then a code field and `Verify code`.

## Driving it with verify

Preconditions:

- The standard settings have the `phone_code` strategy on for sign-in.
- `complete` seeds its own `+clerk_test` user with `host.seedUser({ phone: true })`. `request-code` takes a number from `host.newPhone()`, which no user holds.

- **Request the code.** Run `e2e-tests/bin/control-clerk-ios run custom-flow-sign-in/complete`. Each test launches and taps `e2e.home.customSignIn` on the home. The spec fills `verify.customSignIn.phoneNumber` with the user's phone, taps `verify.customSignIn.sendCode`, and expects `verify.customSignIn.code` and `verify.customSignIn.verifyCode` with no `verify.customSignIn.error`. The form shows the code field only when `clerk.auth.signInWithPhoneCode(phoneNumber:)` returned without an error. Screenshot `custom-code`.
- **Unknown number.** Run `e2e-tests/bin/control-clerk-ios run custom-flow-sign-in/request-code`. It fills a number from `host.newPhone()` and expects `verify.customSignIn.error` to read `Couldn't find your account.`, with no code field. Screenshot `custom-error`.
- **Enter the code.** `complete` then types `CLERK_TEST_CODE` and taps `verify.customSignIn.verifyCode`, which calls `SignIn.verifyCode(_:)`. The form returns to the home only when the sign-in that call returns is `complete`, so `host.expectSignedInAs(user)`, which waits for the home to show the user's email, the seeded user ID, and a session ID, proves it. Screenshot `custom-signed-in`.
- **Proof.** Both specs pass.

## Gotchas

- The form trims spaces from what is typed and changes nothing else, so fill the whole number, `user.phone`, with its `+1`.
- A sign-in error shows in `verify.customSignIn.error`, and the form stays on screen.
- E2EHost shows the form until the form reports that its sign-in is complete. An active session alone does not close it. A sign-in whose code is verified is complete and its session is already active, so the form calls no `setActive`.
- `Couldn't find your account.` is Clerk's message for an identifier no user holds. It comes from the API, so a change of that wording fails `request-code`.
- The screen keeps no state across launches. Every launch starts on the home, and the button opens the form on the phone field.
