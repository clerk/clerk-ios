# TypeScript core prerelease

`ClerkKit` now builds the generated Swift public API in `NativeCore`. Its authentication roots are generated from `SignInFutureResource` and `SignUpFutureResource`; the former native API is not a compatibility facade. `ClerkKitUI` uses these generated resources while preserving its SwiftUI controls and presentation state. The Quickstart and E2E host examples connect one app-owned core and supply it through the SwiftUI environment.

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

Run `make test-native-core` on macOS for the packaged-core contract suite, and `make test-ui` for the presentation suite. Run `scripts/test-native-core.sh` for the separate-process credential checks. The proof executes the packaged bundle, generated SSO, local reset, explicit finalization, token retrieval and sign-out with deterministic HTTP fixtures. It also seeds an isolated prior-format Keychain identity, restores it from separate process launches, clears it and verifies that it remains cleared. It does not read the developer's credentials. A physical-device upgrade from a released app with a real signed-in user remains a release gate.

## Native email links

Email-link preparation uses the configured callback URL and saves its PKCE verifier in a separate secure record scoped to the instance. The TypeScript core validates the saved record, expiration and callback before completing it. Forward incoming URLs to `clerk.handleAuthCallback`. It returns the generated sign-in or sign-up resource without activating a session; custom interfaces must explicitly finalize a complete result. The callback also remains available as `clerk.authCallback` until `clearAuthCallback(id)` consumes it. `AuthView` consumes this record and finalizes as part of its existing presentation flow.

Pending links survive process restart. The previous iOS pending-link record requires a matching `LegacyKeychainConfiguration.publishableKey`; Android uses the matching cached publishable key or explicit `legacyPublishableKey`. Clearing a pending link leaves the client credential intact. Android callers can supply `magicLinkAttestation` when their instance requires an attestation provider.

## Biometric credentials

The generated `clerk.biometricCredentials` resource owns enrollment, local selection, server validation, revocation and cleanup in TypeScript. Use its `canEnroll` state and asynchronous availability methods to drive presentation. `clerk.signIn.biometricCredential()` authenticates through the canonical future sign-in resource and leaves finalization explicit. Native hosts create device-held EC keys and return public material or challenge signatures; private keys and local key identifiers are excluded from observable snapshots.

The adapters preserve the previous Secure Enclave / Android Keystore key names and migrate scoped local metadata using the same explicit instance checks as pending email links. Biometric metadata has a separate secure-storage entry. Account deletion records unsuccessful local key cleanup for retry on restart. The system prompt still requires enrolled biometrics and an appropriate presentation host; device-passcode fallback follows the selected platform policy.

## Bundle updates

From the clean JavaScript repository, run `node packages/mobile-runtime/pack.mjs IOS_REPOSITORY ANDROID_REPOSITORY`. Packaging verifies generated contracts, rebuilds the bundle, pins the source commit and SHA-256, and copies the canonical generated API. Commit these resources together. Do not manually modify generated Swift or remotely replace executable code. Review `NativeCore/public-api.txt` for native source compatibility on every update.

The pre-existing `ClerkKitTests` target is still present during migration and is not yet compatible with the generated API. Its legacy request, resource, and lifecycle tests require an explicit coverage audit before retirement. The dedicated contract and UI schemes do not disable that target.

## Previous native API

The [separate migration guide](Migration/README.md) records the audited main baseline, old public declarations, call changes, unavailable features, and the legacy-test coverage audit. The old native test trees remain pending their explicit assertion-level migration.
