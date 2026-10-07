# Sign up

A new user types a new email address or phone number into AuthView in sign-up mode, verifies it with a one-time code, sets a password, and ends up signed in.

## Sub-features

- `complete` accepts the code, takes a password, and signs the new user in.
- `complete-from-sheet` does the same in the sheet that the home's `Sign in` button opens, and the sheet closes itself.
- `phone` starts with a phone number, verifies it by SMS code, then collects the email and the password that the standard settings require.

## How to get to it (user POV)

- Open AuthView in sign-up mode (`authMode: 'signUp'`), type a new email address, and tap Continue.
- Type the code, then a password, and tap Continue.
- For a phone sign-up, tap `Use phone number` on the start screen, type the number, and tap Continue. Type the SMS code, then the email address, its code, and a password.

## Driving it with verify

Preconditions:

- The standard settings allow sign-up with an email code and require a password.
- The spec gets a fresh email from `host.newEmail()`. The address starts with the run's prefix, and that is how the run finds the user the form creates.
- The standard settings take a phone number at sign-up and verify it by SMS code, but they still require an email and a password. `phone.e2e.ts` reserves a number with `host.newPhone()` and gets an email from `host.newEmail()`.

- **Request the code.** Run `e2e-tests/bin/control-clerk-ios run sign-up/complete`. The spec launches with `authMode: 'signUp'`, taps `e2e.auth.signInFullScreen` on the home, fills `clerk.auth.start.identifier`, taps `clerk.auth.start.continue`, and expects `clerk.auth.signUp.code`. Screenshot `signup-code`.
- **Complete sign-up.** The spec then fills `clerk.auth.signUp.code` with `CLERK_TEST_CODE`, waits for `clerk.auth.signUp.password`, fills the one text box on the screen with `Verify-<runId>-Pw1!`, taps `clerk.auth.signUp.continue`, and waits for the home to show `Signed in as` the new email with a user ID. Screenshot `signed-up`.
- **Complete sign-up in the sheet.** The second test of `complete.e2e.ts` launches with `authMode: 'signUp'`, taps `e2e.auth.signIn`, and does the same steps in the sheet. The home is readable only after the sheet has closed, so `Signed in as` the new email is also the proof that the sheet closed itself. Screenshot `signed-up-from-sheet`.
- **Sign up with a phone number.** Run `e2e-tests/bin/control-clerk-ios run sign-up/phone`. The spec taps `clerk.auth.start.identifierSwitcher`, fills `clerk.auth.start.phoneNumber` with the ten digits of the reserved number, taps `clerk.auth.start.continue`, and expects `Check your phone`. Screenshot `signup-phone-code`. It fills `clerk.auth.signUp.code` with `CLERK_TEST_CODE`, fills the email on the `clerk.auth.signUp.emailAddress` screen, taps `clerk.auth.signUp.continue`, expects `Check your email`, fills the code again, sets the password, and waits for the home to show `Signed in as` the email. Screenshot `signed-up-with-phone`.
- **Proof.** Both specs pass. `run.json` lists the email under `identities` with the id of the user the form created.

## Gotchas

- Sign-up mode still uses the start screen's `clerk.auth.start.identifier` field for the email.
- Always take the email from `host.newEmail`. The run finds the user that the form created by the run's prefix in that email, and `attach` refuses a run that shows a user it cannot account for.
- `clerk.auth.signUp.password` matches three nodes once the field has focus: the floating label, the secure field, and the reveal button. Wait on `.first()`, then wait for `screen.getByRole('textbox')` to have a count of 1 before filling it. Two text boxes match for a moment while the code screen is replaced.
- The password field is a secure field, and the screen withholds its value. `host.fill` types the password once and cannot confirm that it landed, so assert on what the form does next.
- After a password is submitted, iOS may cover the app with its own "Save Password?" sheet. `host.expectSignedInAs` and `host.expectSignedOut` tap "Not Now" when that sheet is up.
- The phone field formats the number as it is typed, as in `+1 (201) 555-0142`. `host.fill` types the ten digits and compares only the digits with what the field shows. Type `phone.slice(2)`, because the field already has the `+1` of the US.
- Both code screens use `clerk.auth.signUp.code`. Their titles tell them apart: `Check your phone` and `Check your email`.
- The email and password screens focus their field as they appear, so the field's identifier matches the floating label and the text box. Wait on `.first()`, then fill `screen.getByRole('textbox')` once its count is 1.
- AuthView verifies what was entered before it asks for what is missing, and asks for the email before the password. That order comes from `SignUp.fieldPriority` in `Sources/ClerkKitUI/Extensions/SignUp+Ext.swift`.
