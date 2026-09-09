# TypeScript core prerelease

`ClerkKit` now builds the generated Swift public API in `NativeCore`. Its authentication roots are generated from `SignInFutureResource` and `SignUpFutureResource`; the former native API is not a compatibility facade. `ClerkKitUI` migration is a separate in-progress change.

Create one owner with `try await Clerk.connect(configuration:)`. The configuration requires a publishable key and a registered browser callback URL. Supply browser and passkey presentation closures from `AppleAuthentication` when those capabilities are needed. The library loads and verifies its bundled JavaScriptCore resource; consumers do not build JavaScript. Close the owner when permanently discarding it.

```swift
let configuration = try ClerkConfiguration(
  publishableKey: publishableKey,
  callbackURL: URL(string: "my-app://oauth/callback")!
)
let clerk = try await Clerk.connect(configuration: configuration)
try await clerk.signIn.emailCode.verifyCode(.init(code: code))
if clerk.signIn.status.rawValue == "complete" {
  try await clerk.signIn.finalize()
}
```

Methods apply observable state before returning or throwing. Successful verification can leave another requirement. Finalization can adopt a pending session; inspect its status and current task. Retained objects or nested groups from a reset attempt become invalidated. A cancelled await is not a server rollback.

The application lifecycle adapter reports foreground/background to the TypeScript core. Background activity suppresses proactive token requests. Foreground reload failures are exposed as `CoreRuntime.lastLifecycleError` without permanently disposing the runtime; an explicit method call or later foreground transition can retry through normal core behavior.

## Credential continuity

The default Keychain adapter imports a matching, previously accepted shared-session identity from the prior SDK's scoped namespace. A cleared or conflicting pending identity is never imported. Unscoped `clerkDeviceToken` adoption requires `LegacyKeychainConfiguration(publishableKey:)` matching the current instance; configure the prior service/access group when applicable. New records are scoped by application and publishable key. Clearing writes a durable empty record so restart cannot reimport an old credential.

The adapter never substitutes a development key when secure storage fails. If old state is unavailable, connect starts without a saved credential and the app presents authentication. Keychain access/decode errors are surfaced; the application should resolve entitlement/access configuration before retrying.

Run `scripts/test-native-core.sh` on macOS. The proof executes the packaged bundle, generated SSO, local reset, explicit finalization, token retrieval and sign-out with deterministic HTTP fixtures. It also seeds an isolated prior-format Keychain identity, restores it from separate process launches, clears it and verifies that it remains cleared. It does not read the developer's credentials. A physical-device upgrade from a released app with a real signed-in user remains a release gate.

## Native email links

Email-link preparation uses the configured callback URL and saves its PKCE verifier in a separate secure record scoped to the instance. The TypeScript core validates the saved record, expiration and callback before completing it. Forward incoming URLs to `clerk.handleAuthCallback`. It returns the generated sign-in or sign-up resource without activating a session; custom interfaces must explicitly finalize a complete result. The callback also remains available as `clerk.authCallback` until `clearAuthCallback(id)` consumes it. `AuthView` consumes this record and finalizes as part of its existing presentation flow.

Pending links survive process restart. The previous iOS pending-link record requires a matching `LegacyKeychainConfiguration.publishableKey`; Android uses the matching cached publishable key or explicit `legacyPublishableKey`. Clearing a pending link leaves the client credential intact. Android callers can supply `magicLinkAttestation` when their instance requires an attestation provider.

## Bundle updates

From the clean JavaScript repository, run `node packages/mobile-runtime/pack.mjs IOS_REPOSITORY ANDROID_REPOSITORY`. Packaging verifies generated contracts, rebuilds the bundle, pins the source commit and SHA-256, and copies the canonical generated API. Commit these resources together. Do not manually modify generated Swift or remotely replace executable code. Review `NativeCore/public-api.txt` for native source compatibility on every update.
