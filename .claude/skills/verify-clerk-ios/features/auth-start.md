# Auth start

A signed-out user opens AuthView and sees the identifier field and the Continue button for the configured instance.

## Sub-features

- `auth-start-home` opens AuthView as a sheet from the E2EHost home sign-in button.
- `auth-start-direct` opens AuthView as the root screen with no tap.

## How to get to it (user POV)

- Tap the `Sign in` button on the home screen while signed out.
- Launch the app straight into AuthView (`verifyScreen auth`), which is how a host app shows AuthView as its root.

## Driving it with verify

Preconditions:

- `.claude/skills/verify-clerk-ios/bin/control-clerk-ios doctor` passes apart from `build`.
- The spec declares no settings, so it runs on the standard instance.

- **Home button.** Run `.claude/skills/verify-clerk-ios/bin/control-clerk-ios run auth-start`. The spec launches `screen: 'home'`, checks `environmentLoaded` true and `signedIn` false, taps `e2e.auth.signIn`, and expects `clerk.auth.start.identifier` and `clerk.auth.start.continue`. Screenshot `auth-start`.
- **Direct launch.** The same run's second test launches `screen: 'auth'` and expects `state.screen` to be `auth`, `lastError` null, and `clerk.auth.start.identifier` visible.
- **Proof.** `specs/golden/auth-start/auth-start.e2e.ts` passes. The run directory holds `video.mp4` and `screenshots/auth-start.png`.

## Gotchas

- A missing or rejected key shows `state.screen` `error` and `lastError.code` `invalid_publishable_key` instead of an empty AuthView. Read the `instances` and `settings` checks of `.claude/skills/verify-clerk-ios/bin/control-clerk-ios doctor` first.
- Behind an HTTPS debugging proxy such as Proxyman, a simulator that does not trust the proxy's CA shows only the AuthView header. Lane simulators clone the template for this reason. `doctor`'s `proxy-trust` check catches drift.
- AuthView remembers identifiers only when asked. E2EHost turns that off, so the field starts empty on every launch.
