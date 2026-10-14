# Sign in with an SMS code

An existing user enters their phone number, asks for a one-time SMS code instead of their password, and signs in with the code.

## Sub-features

- `complete` reaches the SMS code screen for a test user who has a phone and a password, through the password screen and `Use another method`, types `424242`, and lands signed in on the home.

## How to get to it (user POV)

- Tap `Sign in` on the home, switch the start screen to the phone field, type the number, and tap Continue. A user with a password sees the password screen first. Tap `Use another method`, then `Send SMS code to <number>`.

## Driving it with verify

Preconditions:

- The standard settings have the `phone_code` strategy on for sign-in.
- The spec seeds a `+clerk_test` user with `host.seedUser({ phone: true, password: true })` and launches on the home. It never types the password.

- **Request the code.** Run `e2e-tests/bin/control-clerk-ios run sign-in-phone-code/complete`. It expects `Signed out` on the home, taps `e2e.auth.signIn`, taps `clerk.auth.start.identifierSwitcher`, fills `clerk.auth.start.phoneNumber` with the ten digits of the user's phone, taps `clerk.auth.start.continue`, and expects `clerk.auth.signIn.password`. It taps `clerk.auth.signIn.useAnotherMethod`, expects and taps `clerk.auth.signIn.alternativeMethod.phone_code`, and expects `clerk.auth.signIn.code` with `Check your phone` and the user's number on the code screen. Screenshots `phone-password-screen`, `phone-methods`, and `phone-code-screen`.
- **Enter the code.** It fills `clerk.auth.signIn.code` with `CLERK_TEST_CODE` and waits for the home to show `Signed in as` the seeded user's email with that user's ID. The home's sheet closes when the flow completes, and the home is readable only after that, so reaching it proves the sheet closed. Screenshot `signed-in-with-phone-code`.
- **Proof.** The spec passes, and screenshot `signed-in-with-phone-code` shows the home with the seeded user's email and ID.

## Gotchas

- The code screen shows the number as `+1 (201) 555‑01xx`, with a non-breaking hyphen (U+2011) before the last four digits. `asShownByClerk` in `specs/phone.ts` builds that text. The number is both a button and the text inside it, so the spec takes `.first()`.
- `Check your phone` has no identifier, so that check uses text.
