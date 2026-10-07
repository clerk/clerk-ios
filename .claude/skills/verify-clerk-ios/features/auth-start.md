# Auth start

A signed-out user opens AuthView and sees the start screen, where they enter an email, username, or phone number.

## Sub-features

- `auth-start-home` opens AuthView as a sheet from the E2EHost home sign-in button.
- `auth-start-full-screen` opens AuthView as the root of the window from the home's full-screen sign-in button.
- `auth-start-dismiss` closes the sheet with its close button, shows the home again, and opens the sheet again.
- `auth-start-initial-identifier` opens AuthView on the phone field, holding the number the app passed to `initialIdentifier(_:)`.

## How to get to it (user POV)

- Tap the `Sign in` button on the home screen while signed out.
- Tap the `Sign in full screen` button on the home screen, which shows AuthView the way an app shows it as its root.
- Tap the close button of the sheet to go back to the home screen.
- Open the sign-in screen from an app that already knows the phone number. The screen opens with that number in it.

## Driving it with verify

Preconditions:

- `.claude/skills/verify-clerk-ios/bin/control-clerk-ios doctor` fails no check other than `build`.
- The spec declares no settings, so it runs on the standard settings.
- The first three tests need no user. The fourth seeds one with `host.seedUser({ phone: true, password: true })`.

- **Full screen.** Run `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run auth-start`. The first test taps `e2e.auth.signInFullScreen` and expects `clerk.auth.start.identifier` and no `clerk.dismissButton`, because E2EHost shows that AuthView with `isDismissible: false`. Screenshot `auth-full-screen`.
- **Home button and dismiss.** The second test launches the app, expects `Signed out` on the home, taps `e2e.auth.signIn`, and expects `clerk.auth.start.identifier` and `clerk.auth.start.continue`. Screenshot `auth-start`. It then taps `clerk.dismissButton`, waits for the home to show `Signed out`, and expects no `clerk.auth.start.identifier`. Screenshot `auth-dismissed`. It then taps `e2e.auth.signIn` again and expects the identifier field.
- **Initial identifier.** The third test launches in `signIn` mode with the user's phone as `initialIdentifier` and taps `e2e.auth.signInFullScreen`, and E2EHost shows `AuthView().initialIdentifier(<that phone>)`. AuthView then opens on the phone field and shows no `clerk.auth.start.identifier`. Three nodes carry `clerk.auth.start.phoneNumber`: the label `Enter your phone number`, the country code, and the text field. The test expects the second to read `+1`, the text field to hold the rest of the number as `(201) 555-01xx`, and `clerk.auth.start.identifier` to be absent. It then taps `clerk.auth.start.continue` and expects `clerk.auth.signIn.password`. Screenshots `auth-initial-identifier` and `auth-initial-identifier-accepted`.
- **Proof.** `specs/golden/auth-start/auth-start.e2e.ts` passes. The run directory holds `video.mp4` and the five screenshots.

## Gotchas

- A missing or malformed publishable key shows the host's error screen, `Something went wrong` with the reason, instead of an empty AuthView. `host.launch` fails with that reason. Read the `instances` and `settings` checks of `.claude/skills/verify-clerk-ios/bin/control-clerk-ios doctor` first.
- Behind an HTTPS debugging proxy, a simulator that does not trust the proxy's CA shows only the AuthView header. See `doctor`'s `proxy-trust` check.
- `Signed out` on the home is readable only after the sheet has closed, which is how the dismiss test knows the sheet is gone.
- AuthView remembers identifiers between launches by default. E2EHost turns that off with `persistsIdentifiers(false)`, so the field starts empty on every launch that passes no `initialIdentifier`.
- The identifier is a launch input, `verifyInitialIdentifier`. E2EHost has no element of its own for it. The full-screen AuthView reads it, and the AuthView in the home's sheet does not.
- The phone text field reports the number as its value and has no text, so assert on it with `toHaveValue`.
