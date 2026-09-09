# Legacy test audit

Baseline: `02f98f89a19b6c079517c9aae07df7edd0e600e5`. This is a file-level ownership and migration audit of the old native API suite, with exact test declarations retained in [legacy-tests.json](legacy-tests.json). Parameterized cases are not expanded; declarations and helper functions are not a coverage percentage.

Unreviewed old tests remain retained while assertion-level platform and coverage migration is incomplete. The browser/passkey and utility assertion audits below record reviewed file retirements after passing replacement checks. No file in this inventory is claimed to pass unchanged against the new API. Do not remove tests merely because the generated API compiles. Domain tests that only assert calls into a deleted native service should be retired with that service; retained public behavior must be checked through its current owner. The lists below identify where that decision belongs and explicitly preserve unresolved gates.

Native UI presentation tests are outside this inventory and remain in their existing test target. The migration changes resource calls and owner injection, not the intended screen layout or interaction behavior.

The [browser assertion audit](browser-test-audit.md) now maps every old browser
presentation test to the current adapter, records the changed cancellation scope,
and includes a verified regression test for stale callbacks. The
[passkey assertion audit](passkey-test-audit.md) covers request restrictions and
explicit malformed-input rejection. Other categories below still require their
own assertion-level review. The [utility assertion audit](utility-test-audit.md)
separates retained presentation/serialization/PKCE/packaging assertions from
removed helper APIs and unresolved callback/state behavior.
The [configuration assertion audit](configuration-test-audit.md) records exact
key-validation replacements and intentionally removed configuration options.
The [owner replacement audit](reconfiguration-test-audit.md) reviews all 24 old
global reconfiguration tests and records the new close/reconnect contract,
including the Swift late-callback regression and retained release limitations.
The [client response audit](client-response-test-audit.md) records all 33 response
state and ordering declarations, the shared response-ordering fix, organization
selection checks, and the unavailable watch behaviors.
The [Keychain assertion audit](keychain-test-audit.md) records actual persisted
formats, backend precedence, durable clears and unresolved shared-session gates.
The [HTTP assertion audit](http-test-audit.md) separates URLSession execution checks
from removed native middleware and unresolved core identity assertions.
The [lifecycle assertion audit](lifecycle-test-audit.md) maps the three old lifecycle
files to packaged-core notification/recovery checks or retired private polling policy.
The [callback assertion audit](callback-test-audit.md) records restored email-link
route forms, nonce semantics and the remaining tokenless startup assertion.
The [authentication service assertion audit](auth-service-test-audit.md) maps all
42 old sign-in/sign-up service tests to their TypeScript owner, restored locale
behavior, request continuity tests, or explicitly removed private startup markers.
The [error assertion audit](error-test-audit.md) maps the old constructors and
DTO checks to structured native failures and explicit new-major API changes.
The [value assertion audit](value-test-audit.md) covers factors, OIDC parameters,
provider presentation and instance-mode values, including the corrected union projection.

The [JWT assertion audit](jwt-test-audit.md) maps the removed native parser to shared decoding and generated token-result checks.
The [session selection audit](session-utility-test-audit.md) checks canonical selection and readable resource results after expiry.
The [environment assertion audit](environment-test-audit.md) maps all 24 old environment tests, partial-setting defaults, and generated reload behavior.
The [removed proxy/logging audit](removed-utility-test-audit.md) records unavailable configuration and removed private helper semantics.

## Configuration validation

Replacement owner / evidence: NativeCoreContractTests/ClerkConfigurationTests.swift (iOS); NativeCoreTests/Unit/ClerkConfigurationTest.kt (Android).

Valid test/live keys, whitespace, malformed keys, invalid callback routes, and structured errors are exercised. Old global configuration mutation/proxy behavior is not retained.

| Old test file | Source test declarations |
| --- | --- |
| [Tests/Configuration/ClerkOptionsTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Configuration/ClerkOptionsTests.swift) | 11 |
| [Tests/Configuration/ConfigurationManagerTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Configuration/ConfigurationManagerTests.swift) | 17 |
| [Tests/Configuration/RedirectConfigTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Configuration/RedirectConfigTests.swift) | 5 |

## Core lifecycle and token policy

Replacement owner / evidence: JavaScript packages/mobile-runtime/test/protocol.test.mjs; clerk-js SessionTokenCache/Session tests; native lifecycle adapters.

Background/foreground notifications delegate reload and token policy to TypeScript. Do not migrate native polling or token-cache algorithms. Process death, native cancellation and all foreground failure paths still require platform evidence.

| Old test file | Source test declarations |
| --- | --- |
| [Tests/Domains/Auth/Session/SessionTokenFetcherTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/Session/SessionTokenFetcherTests.swift) | 23 |
| [Tests/Domains/Auth/TokenFreshnessTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/TokenFreshnessTests.swift) | 14 |
| [Tests/Lifecycle/LifecycleManagerTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Lifecycle/LifecycleManagerTests.swift) | 5 |
| [Tests/Lifecycle/SessionPollingManagerTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Lifecycle/SessionPollingManagerTests.swift) | 24 |
| [Tests/Lifecycle/TaskCoordinatorTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Lifecycle/TaskCoordinatorTests.swift) | 6 |

## Core state, request ownership and races

The [identity controller assertion audit](identity-controller-test-audit.md)
records all twelve controller declarations, new embedded persistence checks,
and unresolved tokenless-client/credential-rotation differences. The old
controller file remains retained. It also maps the two organization collection
entry-point tests to current generated HTTP/resource outcomes.

Replacement owner / evidence: JavaScript packages/mobile-runtime/test/{protocol,attached-core,magic-link,biometrics}.test.mjs and clerk-js resource/request tests; native CoreRuntime and host integration.

The old sequence gates, mutable singleton, middleware pipeline and activation coordinator are not retained as a second state machine. Preserve public race/error outcomes in core tests. Late finalization, reset, sign-out, canceled host effects, shared-owner detach and stale resource handles are tested through the new protocol. This is not a one-for-one replacement of every old race test.

| Old test file | Source test declarations |
| --- | --- |
| [Tests/Core/ClerkIdentityControllerTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Core/ClerkIdentityControllerTests.swift) | 12 |
| [Tests/Core/ClerkReconfigureTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Core/ClerkReconfigureTests.swift) | 24 |
| [Tests/Core/ClerkResponseClientStateTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Core/ClerkResponseClientStateTests.swift) | 27 |
| [Tests/Core/ClerkTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Core/ClerkTests.swift) | 92 |
| [Tests/Core/ClientResponseOrderingGateTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Core/ClientResponseOrderingGateTests.swift) | 6 |
| [Tests/Middleware/ClerkAuthEventEmitterResponseMiddlewareTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Middleware/ClerkAuthEventEmitterResponseMiddlewareTests.swift) | 7 |
| [Tests/Middleware/ClerkClientSyncResponseMiddlewareTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Middleware/ClerkClientSyncResponseMiddlewareTests.swift) | 19 |
| [Tests/Middleware/ClerkDeviceTokenResponseMiddlewareTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Middleware/ClerkDeviceTokenResponseMiddlewareTests.swift) | 3 |
| [Tests/Middleware/ClerkHeaderRequestMiddlewareTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Middleware/ClerkHeaderRequestMiddlewareTests.swift) | 13 |
| [Tests/Middleware/ClerkInvalidAuthResponseMiddlewareTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Middleware/ClerkInvalidAuthResponseMiddlewareTests.swift) | 1 |
| [Tests/Middleware/ClerkRateLimitRetryMiddlewareTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Middleware/ClerkRateLimitRetryMiddlewareTests.swift) | 10 |
| [Tests/Middleware/NetworkingPipelineResponseMiddlewareOrderTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Middleware/NetworkingPipelineResponseMiddlewareOrderTests.swift) | 1 |
| [Tests/Networking/ClerkAPIClientTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Networking/ClerkAPIClientTests.swift) | 19 |

## Native diagnostics and package resources

Replacement owner / evidence: Native logging, resource manifests, bundled-core SHA checks and package build tests.

Keep credential redaction and package resource checks. The new core does not retain the old logging callback API. Privacy declarations must describe APIs actually used by each shipped target; copying an obsolete expected manifest is not sufficient.

| Old test file | Source test declarations |
| --- | --- |
| [Tests/Logging/ClerkLoggerTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Logging/ClerkLoggerTests.swift) | 7 |
| [Tests/Utils/PrivacyManifestTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Utils/PrivacyManifestTests.swift) | 1 |
| [Tests/Utils/SessionStatusLoggerTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Utils/SessionStatusLoggerTests.swift) | 12 |
| [Tests/Utils/VersionTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Utils/VersionTests.swift) | 2 |

## Live service integration

Replacement owner / evidence: Native released-app upgrade and device test plan.

Retain as a required live-service proof. Fixture servers do not establish production behavior, real credentials, callback registration or account continuity.

| Old test file | Source test declarations |
| --- | --- |
| [Tests/Integration/AuthAndClientIntegrationTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Integration/AuthAndClientIntegrationTests.swift) | 1 |
| [Tests/Integration/EnvironmentIntegrationTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Integration/EnvironmentIntegrationTests.swift) | 1 |
| [Tests/Integration/IntegrationTestHelpers.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Integration/IntegrationTestHelpers.swift) | 0 |

## Platform prompts and lifecycle

Replacement owner / evidence: iOS NativeCore/AppleAuthentication.swift, AppleBiometricKeyManager.swift; Android NativeCore/Android platform hosts and NativeCoreTests/Android/PasskeyRequestTest.kt.

Keep tests of WebAuthn encoding, callback routes, cancellation, presentation lifetime and key access. Native request encoding is tested, but mocked core/credential results do not prove a successful physical-device browser, passkey, biometric or attestation prompt. These files require assertion-level migration before retirement.

| Old test file | Source test declarations |
| --- | --- |
| [Tests/Domains/Auth/BiometricCredential/BiometricCredentialKeyManagerTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/BiometricCredential/BiometricCredentialKeyManagerTests.swift) | 16 |
| [Tests/Domains/Auth/Passkey/PasskeyHelperTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/Passkey/PasskeyHelperTests.swift) | 1 |
| [Tests/Utils/JSONWebAuthnTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Utils/JSONWebAuthnTests.swift) | 3 |
| [Tests/Utils/WebAuthenticationTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Utils/WebAuthenticationTests.swift) | 5 |

## Presentation and value helpers

Replacement owner / evidence: iOS Tests/UI; Android source/ui/src/test; generated environment and resource fields.

Existing native presentation tests remain. Factor sorting, provider display values, organization list state and typography belong to UI or canonical source helpers. Audit shared helper assertions before deleting them from the old API test tree.

| Old test file | Source test declarations |
| --- | --- |
| [Tests/Domains/Auth/OAuthProviderTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/OAuthProviderTests.swift) | 4 |
| [Tests/Domains/Auth/OIDCPromptTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/OIDCPromptTests.swift) | 6 |
| [Tests/Domains/Organization/OrganizationAccountListDataSourceTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Organization/OrganizationAccountListDataSourceTests.swift) | 10 |
| [Tests/Utils/ExternalAuthUtilsTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Utils/ExternalAuthUtilsTests.swift) | 6 |
| [Tests/Utils/LocaleUtilsTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Utils/LocaleUtilsTests.swift) | 2 |
| [Tests/Utils/OptionalStringExtensionsTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Utils/OptionalStringExtensionsTests.swift) | 1 |
| [Tests/Utils/SessionUtilsTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Utils/SessionUtilsTests.swift) | 16 |
| [Tests/Utils/StringExtensionsTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Utils/StringExtensionsTests.swift) | 8 |

## Native secure storage and migration

Replacement owner / evidence: iOS NativeCoreTests/CredentialUpgradeProof.swift and scripts/test-native-core.sh; Android NativeCoreTests/Android/CredentialUpgradeTest.kt; JavaScript magic-link and biometric suites.

Matching legacy identity, purpose separation, durable clears, scoped metadata and restart recovery have dedicated proofs. Old shared owner-slot conflict resolution is unavailable. Actual released-app upgrades and entitlement/Keystore failure behavior remain release gates.

| Old test file | Source test declarations |
| --- | --- |
| [Tests/Configuration/KeychainConfigTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Configuration/KeychainConfigTests.swift) | 5 |
| [Tests/Dependencies/DependencyContainerKeychainTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Dependencies/DependencyContainerKeychainTests.swift) | 9 |
| [Tests/Domains/Auth/BiometricCredential/BiometricCredentialLocalStoreTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/BiometricCredential/BiometricCredentialLocalStoreTests.swift) | 21 |
| [Tests/Storage/CacheManagerTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Storage/CacheManagerTests.swift) | 14 |
| [Tests/Storage/ClerkKeychainKeyTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Storage/ClerkKeychainKeyTests.swift) | 2 |
| [Tests/Storage/MigratingKeychainStorageTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Storage/MigratingKeychainStorageTests.swift) | 10 |
| [Tests/Storage/SystemKeychainTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Storage/SystemKeychainTests.swift) | 13 |
| [Tests/TestSupport/InMemoryKeychain.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/TestSupport/InMemoryKeychain.swift) | 0 |

## Generated codecs and structured errors

Replacement owner / evidence: JavaScript packages/native-bindings/test; packages/mobile-runtime/test/{mapped-records,protocol,selected-code-factors}.test.mjs; native packaged-core suites.

Old Codable/Retrofit enum defaults, DTO constructors and result adapters belong to a removed model. New codecs preserve optional/null distinctions, unknown output enum values, typed unions and error kinds. Native round trips need their own assertions; do not infer them from old DTO tests.

| Old test file | Source test declarations |
| --- | --- |
| [Tests/Configuration/InstanceEnvironmentTypeTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Configuration/InstanceEnvironmentTypeTests.swift) | 6 |
| [Tests/Domains/Auth/FactorTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/FactorTests.swift) | 3 |
| [Tests/Domains/Environment/AuthConfigDecodingTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Environment/AuthConfigDecodingTests.swift) | 3 |
| [Tests/Domains/Environment/AuthConfigTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Environment/AuthConfigTests.swift) | 2 |
| [Tests/Domains/Environment/DisplayConfigDecodingTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Environment/DisplayConfigDecodingTests.swift) | 4 |
| [Tests/Domains/Environment/OrganizationSettingsDecodingTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Environment/OrganizationSettingsDecodingTests.swift) | 5 |
| [Tests/Errors/ErrorTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Errors/ErrorTests.swift) | 19 |
| [Tests/Utils/HTTPURLResponseExtensionsTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Utils/HTTPURLResponseExtensionsTests.swift) | 7 |
| [Tests/Utils/JSONUtilitiesTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Utils/JSONUtilitiesTests.swift) | 37 |
| [Tests/Utils/JWTDecoderTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Utils/JWTDecoderTests.swift) | 16 |
| [Tests/Utils/PKCETests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Utils/PKCETests.swift) | 2 |
| [Tests/Utils/RetryingOperationTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Utils/RetryingOperationTests.swift) | 4 |
| [Tests/Utils/URLEncodedFormEncoderTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Utils/URLEncodedFormEncoderTests.swift) | 53 |

## TypeScript domain ownership

Replacement owner / evidence: JavaScript packages/clerk-js/src/core/resources/__tests__; packages/mobile-runtime/test/{protocol,sso,selected-code-factors,mobile-sso,mobile-identifier-google,passkey,apple-identity,external-account,magic-link,biometrics}.test.mjs; native packaged-core suites.

Tests expecting a native service mock or request-builder call no longer exercise the implementation. Port their public outcomes to the actual TypeScript owner when the selected contract retains the behavior. Matching method names are not a coverage proof.

| Old test file | Source test declarations |
| --- | --- |
| [Tests/Core/OrganizationsTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Core/OrganizationsTests.swift) | 2 |
| [Tests/Domains/Auth/AuthAppleTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/AuthAppleTests.swift) | 7 |
| [Tests/Domains/Auth/AuthTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/AuthTests.swift) | 38 |
| [Tests/Domains/Auth/BiometricCredential/BiometricCredentialServiceTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/BiometricCredential/BiometricCredentialServiceTests.swift) | 5 |
| [Tests/Domains/Auth/BiometricCredential/BiometricCredentialTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/BiometricCredential/BiometricCredentialTests.swift) | 4 |
| [Tests/Domains/Auth/BiometricCredential/BiometricCredentialsTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/BiometricCredential/BiometricCredentialsTests.swift) | 50 |
| [Tests/Domains/Auth/MagicLinkServiceTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/MagicLinkServiceTests.swift) | 1 |
| [Tests/Domains/Auth/MagicLinkTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/MagicLinkTests.swift) | 6 |
| [Tests/Domains/Auth/Passkey/PasskeyServiceTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/Passkey/PasskeyServiceTests.swift) | 4 |
| [Tests/Domains/Auth/Passkey/PasskeyTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/Passkey/PasskeyTests.swift) | 4 |
| [Tests/Domains/Auth/Session/SessionAuthorizationTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/Session/SessionAuthorizationTests.swift) | 28 |
| [Tests/Domains/Auth/Session/SessionServiceTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/Session/SessionServiceTests.swift) | 18 |
| [Tests/Domains/Auth/Session/SessionTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/Session/SessionTests.swift) | 18 |
| [Tests/Domains/Auth/SignIn/SignInServiceTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/SignIn/SignInServiceTests.swift) | 26 |
| [Tests/Domains/Auth/SignIn/SignInTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/SignIn/SignInTests.swift) | 26 |
| [Tests/Domains/Auth/SignUp/SignUpServiceTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/SignUp/SignUpServiceTests.swift) | 16 |
| [Tests/Domains/Auth/SignUp/SignUpTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/SignUp/SignUpTests.swift) | 8 |
| [Tests/Domains/Billing/BillingTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Billing/BillingTests.swift) | 25 |
| [Tests/Domains/Client/ClientServiceTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Client/ClientServiceTests.swift) | 2 |
| [Tests/Domains/Client/ClientTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Client/ClientTests.swift) | 10 |
| [Tests/Domains/Environment/EnvironmentServiceTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Environment/EnvironmentServiceTests.swift) | 1 |
| [Tests/Domains/Environment/EnvironmentTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Environment/EnvironmentTests.swift) | 9 |
| [Tests/Domains/Organization/OrganizationCreationDefaultsTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Organization/OrganizationCreationDefaultsTests.swift) | 3 |
| [Tests/Domains/Organization/OrganizationServiceTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Organization/OrganizationServiceTests.swift) | 38 |
| [Tests/Domains/Organization/OrganizationTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Organization/OrganizationTests.swift) | 35 |
| [Tests/Domains/User/EmailAddress/EmailAddressServiceTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/User/EmailAddress/EmailAddressServiceTests.swift) | 4 |
| [Tests/Domains/User/EmailAddress/EmailAddressTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/User/EmailAddress/EmailAddressTests.swift) | 3 |
| [Tests/Domains/User/ExternalAccount/ExternalAccountServiceTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/User/ExternalAccount/ExternalAccountServiceTests.swift) | 2 |
| [Tests/Domains/User/ExternalAccount/ExternalAccountTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/User/ExternalAccount/ExternalAccountTests.swift) | 1 |
| [Tests/Domains/User/PhoneNumber/PhoneNumberServiceTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/User/PhoneNumber/PhoneNumberServiceTests.swift) | 6 |
| [Tests/Domains/User/PhoneNumber/PhoneNumberTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/User/PhoneNumber/PhoneNumberTests.swift) | 5 |
| [Tests/Domains/User/UserServiceTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/User/UserServiceTests.swift) | 28 |
| [Tests/Domains/User/UserTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/User/UserTests.swift) | 18 |

## Old test infrastructure

Replacement owner / evidence: Fixtures generated by the TypeScript state serializer and the native packaged-core fixtures.

A helper has no independent pass count. Remove it only when all tests using it have been migrated or explicitly retired.

| Old test file | Source test declarations |
| --- | --- |
| [Tests/Domains/Auth/MockMagicLinkServiceTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/MockMagicLinkServiceTests.swift) | 1 |
| [Tests/TestSupport/JWTTestHelpers.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/TestSupport/JWTTestHelpers.swift) | 1 |
| [Tests/TestSupport/TestHelpers.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/TestSupport/TestHelpers.swift) | 0 |

## Explicitly unavailable legacy feature

Replacement owner / evidence: Migration README: unavailable surfaces.

Hosted portal authentication, live shared-session/watch replication, proxy configuration and offline resource-cache bootstrap have no equivalent in this selected prerelease. These tests are evidence of a product gap, not passing replacement coverage. Apps using these features must not be migrated implicitly.

| Old test file | Source test declarations |
| --- | --- |
| [Tests/Core/SharedSessionIdentityEventTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Core/SharedSessionIdentityEventTests.swift) | 13 |
| [Tests/Core/SharedSessionOwnerSlotClearRecoveryTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Core/SharedSessionOwnerSlotClearRecoveryTests.swift) | 10 |
| [Tests/Core/SharedSessionSyncAdoptionTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Core/SharedSessionSyncAdoptionTests.swift) | 19 |
| [Tests/Core/SharedSessionSyncTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Core/SharedSessionSyncTests.swift) | 80 |
| [Tests/Core/WatchSyncPayloadTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Core/WatchSyncPayloadTests.swift) | 65 |
| [Tests/Domains/Auth/HostedAuthPersistenceTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/HostedAuthPersistenceTests.swift) | 5 |
| [Tests/Domains/Auth/HostedAuthServiceTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/HostedAuthServiceTests.swift) | 4 |
| [Tests/Domains/Auth/HostedAuthTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Domains/Auth/HostedAuthTests.swift) | 23 |
| [Tests/Storage/SharedSessionLocalIdentityStoreTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Storage/SharedSessionLocalIdentityStoreTests.swift) | 10 |
| [Tests/Storage/SharedSessionOwnerSlotStoreTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Storage/SharedSessionOwnerSlotStoreTests.swift) | 14 |
| [Tests/Utils/ProxyConfigurationTests.swift](https://github.com/clerk/clerk-ios/blob/02f98f89a19b6c079517c9aae07df7edd0e600e5/Tests/Utils/ProxyConfigurationTests.swift) | 16 |
