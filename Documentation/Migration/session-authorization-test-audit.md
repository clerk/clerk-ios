# Session authorization migration audit

The native SDKs call canonical `Session.checkAuthorization` through generated bindings. No native authorization helper is added. This covers every test declaration in iOS `Tests/Domains/Auth/Session/SessionAuthorizationTests.swift`. That legacy suite is retired after the replacement checks and explicit contract changes below were verified.

## Public contract

The source `CheckAuthorizationParams` type in `packages/shared/src/types/session.ts` is a union of one role, permission, feature, plan, or no criterion, with optional reverification. Although the internal helper supports AND combinations, the public source type excludes those combinations. Applications requiring several checks must compose separate calls; those calls are not an atomic snapshot across asynchronous updates. The old synchronous `has` alias is not generated.

`factorVerificationAge` is a nullable pair, represented by a generated tuple struct in Swift and Kotlin. Canonical `SessionJSON` requires `factor_verification_age`; explicit null is valid, while omission or a malformed pair fails initialization before the resource becomes observable. An unknown custom reverification input level produces `invalid_bridge_value`, rather than the old helper's false result. Unknown output enum decoding remains forward-compatible; it does not authorize unsupported input values.

## Evidence

- Embedded `packages/mobile-runtime/test/session-authorization.test.mjs`: 41 cases, including token claims, role/permission checks, factor ages, rejected inputs/payloads, and permission revocation after reload. Full embedded suite: 277 passed.
- Canonical `packages/shared/src/__tests__/authorization.spec.ts`: 29 passed.
- Swift `NativeCoreContractTests/SessionAuthorizationTests.swift`: five parameter cases through packaged JavaScriptCore. Full macOS suite: 73 test declarations passed; iOS Simulator: 70 passed.
- Android `NativeCoreTests/Android/SessionAuthorizationTest.kt`: five scenarios through packaged QuickJS; five instrumentation tests passed.

Native cases check generated criteria, local evaluation without HTTP, factor ages, invalid input errors, and revoked permissions after an explicit reload. This is fixture-backed behavioral evidence, not live service or performance acceptance. The packaged runtime is unchanged by this test-only addition.

## Assertion disposition

| Retained legacy test | Replacement or migration difference |
| --- | --- |
| `checkAuthorizationAndHasShareOneImplementation` | Present/missing plans pass. The handwritten has alias is absent from the canonical resource API. |
| `decodesFactorVerificationAge` | Embedded [5, 10] projection passes. Native cases assert both generated tuple fields. |
| `missingFactorVerificationAgeDecodesAsNil` | Changed: canonical SessionJSON requires the field with a pair or null. Explicit null passes; omission fails initialization with invalid_projection:Session.factorVerificationAge. |
| `parsesFeaturesByScope` | Embedded and native checks cover all listed aliases and invalid scopes. |
| `failsWhenNoDimensionWasRequested` | Empty generated case5 returns false on all hosts. |
| `failsPermissionAndRoleWhenOrgContextIsMissing` | Embedded checks cover both role and permission without an active organization. |
| `failsReverificationWhenFactorVerificationAgeIsNil` | Explicit null denies reverification on all hosts. |
| `failsWhenFactorVerificationAgePayloadIsMalformed` | Changed boundary: a one-element pair fails projection at initialization. Canonical helper retains its malformed-array denial test. |
| `requiresAndAcrossBillingAndOrg` | Canonical helper source test passes. Generated public union excludes combined permission and feature input. |
| `requiresAndWithinOrgWhenRoleAndPermissionAreRequested` | Canonical helper source tests pass. Generated public union excludes combined role and permission input. |
| `requiresAndWithinBillingWhenFeatureAndPlanAreRequested` | Canonical helper source tests pass. Generated public union excludes combined feature and plan input. |
| `failsFeatureCheckWhenFeaturesClaimIsMissingOrEmpty` | Embedded empty feature claim denial passes. |
| `failsWhenTokenClaimsAreMissing` | Embedded null-token feature and plan denial passes. |
| `requiresAndAcrossOrgAndBillingCombos` | Canonical helper source tests pass. Generated public union excludes combined organization and billing inputs. |
| `failsMissingFeaturesWhenReverificationWouldPass` | Embedded empty claim and native missing feature deny despite fresh factors. |
| `authorizesPermissionPlusReverificationWhenBothMatch` | Embedded and native permission plus reverification checks pass. |
| `authorizesEveryRequestedDimensionWhenAllThreeMatch` | Canonical helper source test passes. Public union excludes permission plus feature, allowing one criterion with reverification. |
| `authorizesStrictMfaViaGracefulDowngradeWhenNoSecondFactorIsEnrolled` | Embedded and native [0, -1] cases pass. |
| `failsPermissionPlusReverificationWhenNoFactorsAreEnrolled` | Embedded and native [-1, -1] cases deny. |
| `failsReverificationWhenConfigObjectIsIncompleteOrOutOfRange` | Embedded zero/negative maximum age cases deny; canonical source tests pass. Unknown input level throws invalid_bridge_value on all hosts. Generated custom configuration requires both fields. |
| `failsClosedWithoutUserId` | Embedded session-revocation test supplies null user, matching feature/plan claims and fresh factors. Canonical User hydrates an empty id; all three authorization checks deny. The native wrapper shape differs from the old manually assigned nil user. |
| `splitsFeaturesByScopeIncludingMergedOuAndUo` | Canonical split helper tests pass. Embedded and native checks cover both scopes for ou and uo. |
| `splitByScopeThrowsWhenClaimElementIsMissingAColon` | Canonical helper throw test passes; public embedded authorization denies malformed feature claims. |
| `unscopedFeatureMatchesMergedUserAndOrgIds` | Embedded and native checks authorize both unscoped feature names; embedded missing feature denies. |
| `orgScopedFeatureFailsWithoutActiveOrgClaim` | Embedded fixture without an organization authorizes user scope and denies organization scope. |
| `roleCheckPrefixesOrg` | Embedded and native prefixed/unprefixed admin and wrong-role checks pass. |
| `readsFeaAndPlaFromLastActiveToken` | Embedded and native fixtures use actual JWT claims and check present/missing features and plans. |
| `hasOnCachedTokenStaysUnderOneMillisecond` | Unresolved: old synchronous timing does not measure asynchronous native calls. Physical-device acceptance remains in Documentation/Performance.md. |

The missing-user assertion is covered by the follow-up embedded test; physical-device timing remains unresolved. Retain the legacy file while that acceptance gate is investigated. Session verification service and factor-strategy assertions live in separate legacy files and are outside this authorization inventory.
