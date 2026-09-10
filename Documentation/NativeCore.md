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

The default Keychain adapter imports a matching, previously accepted shared-session identity from the prior SDK's scoped namespace. A coherent token-only identity is imported for canonical refresh even when its old client state is cleared; an empty or conflicting pending credential is never imported. See [token-only credential recovery](Migration/token-only-credential-upgrade.md) for the previous formats and clear protections. An existing adoption marker with no local identity prevents legacy credential fallback; see [adopted identity clearing](Migration/adoption-marker-credential-upgrade.md). Unscoped `clerkDeviceToken` adoption requires `LegacyKeychainConfiguration(publishableKey:)` matching the current instance; configure the prior service/access group when applicable. New records are scoped by application and publishable key. Clearing writes a durable empty record so restart cannot reimport an old credential.

The adapter never substitutes a development key when secure storage fails. If old state is unavailable, connect starts without a saved credential and the app presents authentication. Keychain access/decode errors are surfaced; the application should resolve entitlement/access configuration before retrying.

Run `make test-native-core` on macOS for the packaged-core contract suite, and `make test-ui` for the presentation suite. Run `scripts/test-native-core.sh` for the separate-process credential checks. The proof executes the packaged bundle, generated SSO, local reset, explicit finalization, token retrieval and sign-out with deterministic HTTP fixtures. It also seeds an isolated prior-format Keychain identity, restores it from separate process launches, clears it and verifies that it remains cleared. It does not read the developer's credentials. A physical-device upgrade from a released app with a real signed-in user remains a release gate.

For an opt-in service startup smoke test, set `CLERK_PROOF_PUBLISHABLE_KEY` to a
development publishable key and run `swift run NativeCoreProof --live-startup`.
This proof uses the packaged engine and production HTTP adapter, permits only GET
requests to `/v1/environment` and `/v1/client`, and stores credentials only in memory.
It asserts a loaded, signed-out owner. It does not exercise sign-in or OS prompts.

## Native email links

Email-link preparation uses the configured callback URL and saves its PKCE verifier in a separate secure record scoped to the instance. The TypeScript core validates the saved record, expiration and callback before completing it. Forward incoming URLs to `clerk.handleAuthCallback`. It returns the generated sign-in or sign-up resource without activating a session; custom interfaces must explicitly finalize a complete result. The callback also remains available as `clerk.authCallback` until `clearAuthCallback(id)` consumes it. `AuthView` consumes this record and finalizes as part of its existing presentation flow.

Callback parameters may arrive in the query or fragment, with query values taking precedence. Empty and root-slash callback paths are equivalent, as in the previous native SDK; other paths must match the configured route.

Pending links survive process restart. The previous iOS pending-link record requires a matching `LegacyKeychainConfiguration.publishableKey`; Android uses the matching cached publishable key or explicit `legacyPublishableKey`. Clearing a pending link leaves the client credential intact. Android callers can supply `magicLinkAttestation` when their instance requires an attestation provider.

## Biometric credentials

The generated `clerk.biometricCredentials` resource owns enrollment, local selection, server validation, revocation and cleanup in TypeScript. Use its `canEnroll` state and asynchronous availability methods to drive presentation. `clerk.signIn.biometricCredential()` authenticates through the canonical future sign-in resource and leaves finalization explicit. Native hosts create device-held EC keys and return public material or challenge signatures; private keys and local key identifiers are excluded from observable snapshots.

The adapters preserve the previous Secure Enclave / Android Keystore key names and migrate scoped local metadata using the same explicit instance checks as pending email links. Biometric metadata has a separate secure-storage entry. Account deletion records unsuccessful local key cleanup for retry on restart. The system prompt still requires enrolled biometrics and an appropriate presentation host; device-passcode fallback follows the selected platform policy.

## Bundle updates

From the clean JavaScript repository, run `node packages/mobile-runtime/pack.mjs IOS_REPOSITORY ANDROID_REPOSITORY`. Packaging verifies generated contracts, rebuilds the bundle, pins the source commit and SHA-256, and copies the canonical generated API. Commit these resources together. Do not manually modify generated Swift or remotely replace executable code. Review `NativeCore/public-api.txt` for native source compatibility on every update.

The legacy `ClerkKitTests` target has been retired after the completed
[assertion-level audit](Migration/test-audit.md). `make test` runs the complete
`NativeCoreContractTests` target, and `make test-ui` runs the preserved native
presentation tests. Live integration remains a separate opt-in target.

## Previous native API

The [separate migration guide](Migration/README.md) records the audited main baseline, old public declarations, call changes, unavailable features, and the completed legacy-test assertion audit. Of its 108 inventoried files, 105 are retired and three live integration files are migrated. Physical signed-in upgrades and platform release gates remain open.

## Performance measurements

Run `scripts/benchmark-native-core.sh OUTPUT_JSON` to collect raw fresh-engine startup and generated local-reset timings against the packaged deterministic fixture. The reset check verifies invalidation and the absence of HTTP. The first startup sample is separate from subsequent fresh engines in the same warm process. These are not cold-app or live-network timings.

The Swift script builds the release proof executable and uses `/usr/bin/time -l` to report process-wide peak resident memory. That total includes the harness and system libraries.

Record the OS/device, build mode, core revision/hash and packaged artifact sizes with each run. The provisional release budgets and physical-device measurement protocol are in [Performance.md](Performance.md). The declared Apple targets and current capability/validation limits are in [PlatformSupport.md](PlatformSupport.md).

Release performance limits and outstanding measurements are recorded in [the performance budgets](Performance.md).

Packaging also regenerates the eight shared UI preview fixtures against the current protocol. The fixture generator uses a fixed clock and deterministic entropy; run `node scripts/generate-preview-fixtures.mjs JAVASCRIPT_REPOSITORY ANDROID_REPOSITORY` from the iOS repository to refresh them independently. The Swift proof can decode all eight with `swift run NativeCoreProof --preview-fixtures Sources/ClerkKitUI/Resources/Preview`.

Standalone owners now observe OS connectivity and recover through the shared core. See [connectivity and lifecycle recovery](Migration/connectivity.md).

Apple [biometric installation continuity](Migration/biometric-installation.md) recognizes authorized old markers and reconciles surviving keys through the shared core when the app-container marker is missing. Physical upgrade/reinstall validation remains a release gate.
