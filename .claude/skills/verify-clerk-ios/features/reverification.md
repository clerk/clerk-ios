# Reverification

`ReverificationView` asks a signed-in user to verify their identity again before a sensitive action. It starts a session reverification at a level, shows a screen for the factor it needs, lets the user switch to another method they have, and, at the multi-factor level, moves on to a second factor. It is internal, and an app reaches it only through `clerk.reverify`: around an action, which shows the sheet over whatever the app shows, other sheets included, only when the action asks for reverification, and then runs the action again, or with a requirement, which shows it only when the session does not meet the requirement.

## Sub-features

- `first-factor` reverifies with a password, after a wrong password shows its error. It reverifies with an email code after a wrong code shows its error, with the other methods screen on the way, and with an SMS code picked from the other methods. Closing the sheet makes `clerk.reverify` throw `ReverificationCancelledError`.
- `second-factor` reverifies at the second-factor level with a backup code picked from the other methods of the authenticator app screen, then at the multi-factor level with an email code followed by an authenticator code.
- `reverify-action` runs a protected action from the home without the sheet while the session's first factor is fresh. Once it is stale, it runs the action from inside a sheet the app shows, and the reverification sheet appears over that sheet, takes the password, and runs the action.

## How to get to it (user POV)

- Launch the app signed in. The home has `Reverify 1FA`, `2FA`, and `MFA`, which call `clerk.reverify` around an action that asks for reverification at the first-factor, second-factor, or multi-factor level on its first try, so the sheet opens however fresh the session is, `Protected action`, which calls `clerk.reverify` around an action that needs a first factor verified within the last minute, and `Protected action in a sheet`, which opens a plain sheet with the same action. The line under them, and the one in that sheet, reads `Reverified` after one of the level buttons, `Protected action ran` after a protected action, or `Reverification cancelled`.

## Driving it with verify

Preconditions:

- The standard settings offer a password, email codes, and SMS codes as first factors, and an authenticator app, SMS codes, and backup codes as second factors. The standard settings prefer the password, so a user seeded with `password: true` starts on the password screen and a user without one starts on the email code screen.
- `second-factor` enrolls an authenticator app through the setup-MFA session task, as [Session tasks](./session-tasks.md) describes, and reads one of the backup codes it shows. Its test starts with `await host.useSettings({ config: { 'auth_multi_factor.required_for_sign_up': true }, environment: { 'user_settings.sign_up.mfa.required': true } })`.

- **First factor.** Run `e2e-tests/bin/control-clerk-ios run reverification/first-factor`. The password test taps `e2e.home.reverify.firstFactor`, fills `clerk.reverification.password` with a wrong password, taps `clerk.reverification.continue`, and expects `Password is incorrect`. It fills the seeded password and expects `e2e.home.reverificationResult` to read `Reverified`. Screenshots `password`, `password-wrong`, `reverified`. The email code test seeds a user with a phone and no password, expects the email code screen with the user's email, taps `clerk.reverification.useAnotherMethod`, expects `clerk.reverification.alternativeMethod.phone_code`, goes back, fills `clerk.reverification.code` with `000000`, expects `Incorrect code`, then fills `CLERK_TEST_CODE`. Screenshots `email-code`, `alternatives-first-factor`, `email-code-wrong`. The SMS test picks `clerk.reverification.alternativeMethod.phone_code`. Screenshot `phone-code`. The cancel test taps `clerk.dismissButton` and expects `Reverification cancelled`. Screenshot `cancelled`.
- **Second factor.** Run `e2e-tests/bin/control-clerk-ios run reverification/second-factor`. After the session task, it taps `e2e.home.reverify.secondFactor`, expects the authenticator app prompt, opens the other methods, taps `clerk.reverification.alternativeMethod.backup_code`, fills `clerk.reverification.backupCode`, and expects `Reverified`. It then taps `e2e.home.reverify.multiFactor`, fills the email code, expects the authenticator app prompt with no back button, and fills the code for the next 30-second step. Screenshots `totp`, `alternatives-second-factor`, `backup-code`, `multi-factor-first-step`, `multi-factor-second-step`.
- **Reverify action.** Run `e2e-tests/bin/control-clerk-ios run reverification/reverify-action`. It taps `e2e.home.protectedAction` right after launch and expects `Protected action ran` with no sheet. It waits 150 seconds, taps `e2e.home.protectedActionSheet`, taps `e2e.protectedActionSheet.protectedAction` in that sheet, fills the password, and expects `e2e.protectedActionSheet.reverificationResult` to read `Protected action ran`. Screenshots `protected-action-fresh`, `protected-action-sheet-asks`, `protected-action-after-reverify`.
- **Proof.** All three specs pass. The home's result line is set only after `clerk.reverify` returns, which it does only once the verification completed, the session token was refreshed, and the action ran again, so `Reverified` and `Protected action ran` prove all three.

## States a spec cannot reach

| State | Where the app decides | What it takes |
| --- | --- | --- |
| Passkey, as a first or second factor | `ReverificationView.swift`, `ReverificationDestinationView`, `.passkey` | Associated domains, which the simulator build has none of. MacExampleApp with 1Password runs it, as described under Gotchas. |
| Biometrics, as a first or second factor | `ReverificationFlow.swift`, `usableFactors`, `.biometricCredential` | A biometric credential, whose key generation fails on the simulator with OSStatus -25293 because it has no Secure Enclave. A device or a Mac with Touch ID runs it, with Touch ID sign-in turned on for the instance. Passkey comes first in the order, so the Touch ID screen is reached through `Use another method` after cancelling the passkey prompt. |
| A breached password, which offers a reset code | `ReverificationPasswordView.swift`, `passwordIsPwned` | A seeded password that is in a data breach. The harness generates every password. |
| No factor the screens can verify, which shows `Get help` | `ReverificationFlow.swift`, `handle(_:)` | A user whose only first factor is enterprise SSO. |
| No session, or a start that fails | `ReverificationFlow.swift`, `start(session:hasLocalBiometricCredential:)` | An app that presents the sheet while signed out, or a network failure. |

## Gotchas

- `clerk.reverification.password` matches both the secure field and its revealed twin, so use `.first()`.
- XCTest blanks secure fields in screenshots, including one on the screen under a pushed screen. A screenshot of the other methods screen pushed over the password screen has a black bar across its first row, so the email code test takes it from a user with no password.
- A ticket sign-in verifies the first factor, so `Protected action` runs without the sheet for about two minutes after launch. The session token refreshes about every 50 seconds and carries the factor age in whole minutes, so a one-minute requirement fails only after the age reaches one minute in a refreshed token.
- The authenticator code of the multi-factor step uses the next 30-second step, because the session task used the current one.
- On a Mac, the passkey and Touch ID prompts show only while the app is the frontmost app. A tap sent to a background window starts the request, but macOS finds no window to show it in: the passkey request fails with `ASAuthorizationError` 1004, and the log has `Could not find presentation context`. Let a person click those buttons with the app in front.
- A passkey registration challenge expires. Approving it many minutes later fails with `This verification has expired`, and 1Password may keep the passkey it saved.
- On a Mac, `clerk.reverify` called from inside an app sheet stacks a second sheet. The background click tools only know the first one, so they refuse clicks on the part of the reverification sheet outside it, such as the footer's `Close`. Check `Close` from the main window instead.
- Sign-up on the MacExampleApp instance asks for a password, and the computer-use tools refuse to type into password fields, so a person types it.
