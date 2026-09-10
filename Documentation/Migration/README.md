# Migrating ClerkKit to the TypeScript core

This is a new major API. The audited baseline is `02f98f89a19b6c079517c9aae07df7edd0e600e5` from `clerk/clerk-ios`. The primary API now comes from the TypeScript contracts selected by the JavaScript repository's native binding compiler. SwiftUI views retain their presentation and call those resources directly.

[The source inventory](legacy-api.json) records every audited Swift source file, its content hash, and its declared public syntax, including conditional branches. It includes properties, nested types, initializers, enum cases, and overload labels. It excludes inherited and compiler-synthesized declarations and is not an ABI report. [The test inventory](legacy-tests.json) preserves the old non-UI test declarations and their audit categories. Neither declaration counts nor test counts represent execution coverage.

## Create and retain an owner

Replace `Clerk.configure(...)` and `Clerk.shared` with an application-owned `Clerk` returned by `try await Clerk.connect(configuration:)`. Supply that same instance through `.environment(clerk)` to ClerkKitUI. `connect` throws on configuration, storage, or startup failure. There is no partially initialized global singleton to poll. `clerk.loaded`, `clerk.status`, and generated resource state describe the connected core.

```swift
let configuration = try ClerkConfiguration(
  publishableKey: publishableKey,
  callbackURL: URL(string: "my-app://oauth/callback")!
)
let clerk = try await Clerk.connect(configuration: configuration)
```

The basic connection does not invent a presentation anchor. Supply `browser`, `passkeys`, and `appleIdentity` closures from an application-retained `AppleAuthentication` when needed. The callback URL must match the application's registered route. HTTPS callbacks require a supported platform version and verified application links. Closing an owner invalidates its resources; close and create a new owner when changing instances. `close()` disposes the runtime; it does not sign the account out.

## Authentication call map

All paths below are on the retained owner. Future authentication methods return `Void` and throw structured errors after applying state. A returned `SignIn` or `SignUp` value is no longer the mutation result.

| Previous API | Generated API / migration |
| --- | --- |
| `auth.signIn(identifier)` | `signIn.create(SignInCreateParams(identifier: ...))` |
| `auth.signInWithPassword`, `SignIn.authenticateWithPassword` | `signIn.password(SignInPasswordParams)`; select the generated union case that matches the supplied identifier fields |
| `auth.signInWithEmailCode`, `SignIn.sendEmailCode` | Initialize the attempt if needed, then `signIn.emailCode.sendCode(...)` |
| `auth.signInWithPhoneCode`, `SignIn.sendPhoneCode` | Initialize the attempt if needed, then `signIn.phoneCode.sendCode(...)` |
| `SignIn.verifyCode` | Explicit `signIn.emailCode.verifyCode(...)` or `signIn.phoneCode.verifyCode(...)`; do not infer the factor in a native helper |
| `auth.signInWithEmailLink`, `SignIn.sendEmailLink` | `signIn.emailLink.sendLink(...)`; use the configured callback and forward incoming URLs to `clerk.handleAuthCallback(...)` |
| `SignIn.sendMfaEmailCode`, `verifyMfaCode(type: .emailCode)` | `signIn.mfa.sendEmailCode(...)`, `signIn.mfa.verifyEmailCode(...)` |
| `SignIn.sendMfaPhoneCode`, `verifyMfaCode(type: .phoneCode)` | `signIn.mfa.sendPhoneCode(...)`, `signIn.mfa.verifyPhoneCode(...)` |
| `SignIn.verifyMfaCode` for TOTP or backup codes | `signIn.mfa.verifyTOTP(...)` or `signIn.mfa.verifyBackupCode(...)` |
| `SignIn.sendResetPasswordEmailCode` | `signIn.resetPasswordEmailCode.sendCode(...)` |
| `SignIn.sendResetPasswordPhoneCode` | `signIn.resetPasswordPhoneCode.sendCode(...)` |
| `SignIn.resetPassword` | Verify the selected reset code, then use that group's `submitPassword(...)` |
| `auth.signInWithOAuth`, `SignIn.authenticateWithOAuth` | `signIn.sso(...)`; transfer-aware prebuilt entry uses `clerk.authenticateWithSSO(...)` |
| `auth.startEnterpriseSSO`, `signInWithEnterpriseSSO`, `SignIn.completeEnterpriseSSO` | `signIn.sso(...)` with `enterprise_sso`; the core owns preparation, callback reconciliation, and nonce handling |
| `auth.signInWithApple`, `SignIn.authenticateWithApple` | `signIn.sso(...)` with `oauth_token_apple`, or transfer-aware `authenticateWithSSO(...)`; the native host supplies the identity token |
| `auth.signInWithIdToken`, `SignIn.authenticateWithIdToken` | `signIn.create(...)` with the appropriate strategy and token; token acquisition remains a platform operation |
| `auth.createPasskeySignIn`, `signInWithPasskey`, `SignIn.authenticateWithPasskey` | `signIn.passkey(...)`; the selected flow and native host control presentation, including second-factor preparation |
| `auth.signInWithBiometrics` | `signIn.biometricCredential(...)` |
| `auth.signInWithTicket` | `signIn.ticket(...)` |
| `auth.signUp`, `SignUp.update` | `signUp.create(...)`, `signUp.update(...)`; use generated parameter types |
| `SignUp.sendEmailCode`, `verifyEmailCode` | `signUp.verifications.sendEmailCode()`, `verifyEmailCode(...)` |
| `SignUp.sendPhoneCode`, `verifyPhoneCode` | `signUp.verifications.sendPhoneCode()`, `verifyPhoneCode(...)` |
| `SignUp.sendEmailLink` | `signUp.verifications.sendEmailLink(...)` |
| `auth.signUpWithOAuth`, `signUpWithEnterpriseSSO`, `signUpWithApple` | `signUp.sso(...)` with the selected strategy |
| `auth.signUpWithIdToken` | `signUp.create(...)` with strategy and token |
| `auth.signUpWithTicket` | `signUp.ticket(...)` |
| `auth.completeMagicLink`, `clerk.handle` | `clerk.handleAuthCallback(URL)`; returns an optional generated sign-in/sign-up union and leaves finalization explicit |
| `auth.setActive` | `clerk.setActive(...)`; use this for selecting an existing session or organization |
| `auth.signOut` | `clerk.signOut(...)` |
| `auth.getToken`, `Session.getToken` | `clerk.session?.getToken(...)` |
| `auth.revokeSession`, `Session.revoke` | Find the session in `user.getSessions()` and call the generated `SessionWithActivities.revoke()`; `Session.end()` / `remove()` operate on client sessions and are different endpoints |

Custom flows explicitly finalize a complete attempt:

```swift
try await clerk.signIn.emailCode.verifyCode(.init(code: code))
if clerk.signIn.status == .complete {
  try await clerk.signIn.finalize()
}
// Inspect clerk.session?.status and currentTask before rendering protected content.
```

ClerkKitUI performs the same finalization internally and presents remaining session tasks. Verification success alone does not mean that all requirements have been satisfied. Cancellation stops the local await and eligible platform work; it cannot undo server-side changes.

## Resources and values

| Previous surface | New surface / semantic change |
| --- | --- |
| Mutable Codable `SignIn`, `SignUp`, `User`, `Session`, `Organization` structs | Observable generated resource references; retain handles only for their owner's lifetime |
| Assigning the resource returned by a mutation | Await the method and read the same observed resource; new resources are returned only where the TypeScript contract says so |
| Retaining an attempt across reset or reconfiguration | Reacquire `clerk.signIn` / `clerk.signUp`; old resources and nested groups report invalidation |
| `clerk.refreshEnvironment()` | `clerk.environment.reload()` |
| `clerk.refreshClient()` | Lifecycle recovery belongs to the core; refresh a specific generated resource with its `reload()` where exposed |
| `clerk.organizations.create/get` | `clerk.createOrganization(...)` / `clerk.getOrganization(...)` |
| `User.createBackupCodes()` | `user.createBackupCode()`; recovery values are explicit results, excluded from general observation |
| `User.getSessions()` returning `[Session]` | Generated `SessionWithActivities` records; use the actual returned type |
| `User.setProfileImage`, `Organization.setLogo` taking `Data` | Pass a generated upload value with filename/content type/data in the generated parameter object |
| `User.deleteProfileImage`, `Organization.deleteLogo` | Call `setProfileImage` / `setLogo` with an explicitly null file |
| `EmailAddress.sendCode/verifyCode/destroy` | `prepareVerification(...)` / `attemptVerification(...)` / `destroy()` |
| `PhoneNumber.sendCode/verifyCode/delete` | `prepareVerification(...)` / `attemptVerification(...)` / `destroy()` |
| `ExternalAccount.prepareReauthorization/reauthorize` | One `reauthorize(...)` round trip through the native browser host |
| `Passkey.attemptVerification(credential:)` | No raw credential-submission method on the public passkey resource; `user.createPasskey()` owns registration and its platform challenge |
| Session factor convenience methods | `startVerification`, `prepareFirstFactorVerification`, `attemptFirstFactorVerification`, and their second-factor counterparts; `verifyWithPasskey` remains a native-capability operation |
| `Session.has` | `session.checkAuthorization(...)`; authorization semantics come from TypeScript |
| Page/pageSize organization queries | Generated pagination parameters; convert explicitly and read the generated paginated result |
| Native `JSON` metadata helpers | `JSONValue` only for explicitly supported metadata/claims; ordinary parameters remain generated typed values |
| Closed enum decoding / `.unknown` fallback | Generated raw-value types preserve unknown output strings; input encoding validates allowed values |
| Optional request fields | Plain optional where omission is the only absence; `Field<T>` only where omission, null and a value are distinct |

Methods with the same name still require a parameter/result review. For example, organization invitations, domains, memberships, TOTP, profile metadata, and password changes use the TypeScript parameter objects. Consult `NativeCore/public-api.txt` and the generated declarations for exact signatures. Do not mechanically substitute an old initializer into a new type with the same name.

## Credentials and explicitly unavailable surfaces

A source migration and a credential migration are separate. The new Keychain adapter imports matching, accepted prior-format identity records and preserves durable clears. Configure the previous keychain service/access group and matching publishable key through `LegacyKeychainConfiguration` when required. Never copy a token out of another instance or keep both old and new SDK owners active. See [credential continuity](../NativeCore.md#credential-continuity) for current proofs and limitations.

On macOS, access-group import checks the previous SDK's Data Protection backend
before its legacy backend and does not fall back after a read/entitlement error.
A pending old-version clear for this instance prevents credential import; the new
owner starts signed out and requires fresh authentication. The old recovery
journal is retained for the previous major's shared-slot cleanup. A malformed
journal reports an error. A matching previous adoption marker with no local identity
also prevents legacy token fallback, preserving the previous major's cleared identity.
See [adoption-marker recovery](adoption-marker-credential-upgrade.md) and the [Keychain assertion audit](keychain-test-audit.md)
for the persisted formats, verified behavior and remaining device gates.

The selected prerelease profile does **not** provide these old surfaces:

- `startHostedAuth` and its hosted-portal redemption protocol. Browser OAuth/enterprise SSO is available through the future `sso` methods; it is a different contract.
- `SharedSessionSyncConfig`, `reloadFromSharedStorage`, owner-slot convergence, and WatchConnectivity identity replication. Importing a saved local credential is not live cross-process or phone/watch synchronization.
- `Clerk.Options.proxyUrl`, custom request/response middleware, mutable global configuration, and direct public device-token replacement. The native host executes core-owned HTTP and storage effects; these are not equivalent extension points.
- `clerk.billing` query facades. Payment-method methods reached through `User`/`Organization` remain in the generated graph, but the separate old Billing API is not a selected root.
- Persistent offline resource-cache bootstrap. A saved client credential can be restored, but current startup still needs the core's environment/client requests.
- Public JWT decoding, logging handlers, and old domain-model Codable constructors as compatibility APIs.

Applications using these features must remain on the previous major until an explicit migration is available. This prerelease must not be promoted as a transparent upgrade for them. The source inventory retains their exact declarations so omissions are reviewable. This list is not evidence that the previous major can stop receiving security fixes.

## Test audit and release gates

[The audit](test-audit.md) identifies the replacement owner and unresolved proof for each old test category. Existing SwiftUI tests remain in `Tests/UI`; preserve their presentation assertions. The packaged-core contract suite and platform tests are the executable tests for the generated API. An old test of a removed service mock is not a test of the new owner and must not be reported as passing unchanged.

Before a general release, validate an actual old-major app upgrade with a real signed-in account; platform browser/passkey/biometric prompts on physical devices; supported Apple targets; Expo native-to-JavaScript and JavaScript-to-native changes; and startup, memory, artifact size, and call-overhead measurements against agreed budgets. Generated signature support alone does not establish that a platform capability is available. Publish an explicit supported-profile decision and a bounded previous-major maintenance policy with the prerelease.

## Removed implementation

The replaced native domain source tree has been deleted from this major. The linked baseline and hashed source inventory preserve its public declarations for migration review. The generated `NativeCore` target is the implementation; no old native authentication fallback is packaged. All 108 files in the legacy test inventory have been reviewed: 105 are retired and the three integration files are migrated. The [19-declaration adoption audit](shared-adoption-test-audit.md) records the final retirement and its still-open physical release gates. `make test` now runs `NativeCoreContractTests`; native UI and live integration retain their own targets. Per-domain assertion audits record replacement evidence and removed contracts.

### Contact deletion and verification

Use generated `EmailAddress.prepareVerification` / `attemptVerification`, `PhoneNumber.prepareVerification` / `attemptVerification`, and `PhoneNumber.destroy` in place of the old send-code, verify-code and phone-delete conveniences. Contact `destroy` methods return `Void`; no `DeletedObject` DTO is returned. Successful deletion applies the server's client update while retained contact wrappers keep their last readable fields. See the [complete contact assertion audit](contact-resource-test-audit.md) for request encoding differences, source ownership and validation limits.

The [recorded Expo shared-owner Simulator journey](../Measurements/expo-shared-owner-simulator.md) verifies both profile-update directions and native sign-out on Hermes for the pinned versions. It does not establish the remaining device, upgrade, or release-performance gates.

The [user resource assertion audit](user-resource-test-audit.md) records exact metadata replacement behavior, single-status user invitation filters, configured external-account callbacks, and explicit TOTP/recovery results, with packaged regression evidence.

The [biometric credential assertion audit](biometric-test-audit.md) maps the old biometric services and local store to the generated API and shared TypeScript owner. Use `signIn.biometricCredential` with explicit finalization; use generated `currentUser: true` selection instead of the old current-user helpers.

The [Apple authentication assertion audit](apple-auth-test-audit.md) records generated Apple transfer and restriction behavior, the shared verification-error serializer correction, and packaged-engine evidence.

The [authentication flow assertion audit](auth-flow-test-audit.md) records legacy flow-kind migration, incomplete callback results, cleanup/ownership checks, and generated authentication parameter coverage.

The [dependency and cache audit](dependency-cache-test-audit.md) distinguishes credential import from removed offline bootstrap and shared-session topology. The [Billing audit](billing-test-audit.md) records the removed query facade and tested generated payment-method collections.

The [hosted portal audit](hosted-portal-test-audit.md) records the removed create/redeem, automatic-activation and shared-slot contracts separately from supported future SSO.

The [token-only credential upgrade](token-only-credential-upgrade.md) preserves prior credentials awaiting canonical refresh while retaining explicit-clear and instance-scoping protections.
