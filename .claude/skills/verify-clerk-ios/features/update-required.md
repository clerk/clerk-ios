# Update required

An instance sets a minimum version for an app. A build below it can't use Clerk: ClerkKitUI covers every scene with an update screen that shows both versions and links to the App Store. Users stay signed in, so they continue where they left off once the build is allowed again.

## Sub-features

- The update screen covers a signed-in user's app on a build below the minimum, with `Your version`, `Required`, and `Go to App Store`.
- Lowering the minimum returns the same user and session.
- The update screen covers a signed-out user's app too.
- A build at the minimum opens as usual.

## How to get to it (user POV)

- A developer sets a minimum on the Clerk Dashboard's `Native applications` page, then a user opens a build below it.

## Driving it with verify

Preconditions:

- The native app settings are off the standard settings, so each test calls `host.useMinimumAppVersion({ minimumVersion, updateUrl })`. It registers `com.clerk.E2EHost` with the application, sets the minimum, and waits for the public environment to show it. When the test ends, the CLI removes the minimum and leaves the registration.
- Clerk's `native_app_force_update` flag must be on for the instance. It's on globally, and with it off the call fails.
- E2EHost's version is `1.0`, its `MARKETING_VERSION` in `Examples/Quickstart/Quickstart.xcodeproj`. The spec uses `2.0` to block it.

- **Blocked, then allowed.** Run `e2e-tests/bin/control-clerk-ios run update-required --grep "signed-in user"`. The spec signs in with a ticket, sets the minimum to `2.0`, and relaunches with `keepStorage: true`. It then lowers the minimum to `1.0`, relaunches, and checks the session ID has not changed.
- **Signed out.** Run `e2e-tests/bin/control-clerk-ios run update-required --grep "signed-out user"`.
- **At the minimum.** Run `e2e-tests/bin/control-clerk-ios run update-required --grep "at the minimum"`.
- **Proof.** `specs/features/update-required/update-required.e2e.ts` passes. The video shows the update screen with `1.0` and `2.0+`, then the home with the same user and session ID.

## States a spec cannot reach

- `Can't update? Get Help` shows only when the instance has a support email (`displayConfig.supportEmail` in `UpdateRequiredView.swift`). The Platform API config has no support email leaf, so a spec cannot set one.
- A screen with no `Go to App Store` needs a minimum with no update URL, and Clerk requires one (`validateNativeAppMinimum` in clerk_go), so only a local patch reaches it.
- An app's own screen needs `updateRequiredViewEnabled: false`, which E2EHost's `Clerk.Options` does not pass, and the home would need to show `appVersionSupportStatus`.
- `Go to App Store` opens an outside app with a placeholder URL, so the spec checks that the button shows and does not tap it.

## Gotchas

- The screen has no accessibility identifiers, so the spec finds it by its text. A change to that wording changes the spec.
- A minimum applies to the next request or launch. The spec relaunches instead of waiting for a running app to foreground.
- The subtitle names the application, which here is the `verify-throwaway-...` name. Don't assert on it.
- The update screen is its own window over the app, so the home's locators aren't on screen while it shows. A launch that expects it needs `landsOn`.
