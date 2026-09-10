# Apple authentication assertion audit

This audit covers all seven declarations in baseline `Tests/Domains/Auth/AuthAppleTests.swift` at `02f98f89a19b6c079517c9aae07df7edd0e600e5`. The baseline file was read completely and its inventory SHA-256 matched before retirement. These tests formerly exercised handwritten native auth orchestration through service mocks. The new owner is `packages/clerk-js/src/utils/authenticateWithMobileSSO.ts`, exposed by generated `Clerk.authenticateWithSSO` in both languages. The broader `AuthTests.swift` file is separately accounted for in the [authentication flow audit](auth-flow-test-audit.md).

## Preserved behavior and corrected error bridge

The shared helper requests Apple identity once, starts with sign-up for an automatic transferable flow, preserves profile names and unsafe metadata, transfers an existing account to sign-in, and limits restricted-sign-up fallback to the automatic Apple flow. Both `sign_up_mode_restricted` and `sign_up_restricted_waitlist` permit existing-account fallback while keeping new accounts blocked with the original restriction error. An unrelated sign-up error never starts sign-in. Explicit sign-up does not silently fall back. The low-level result leaves session finalization explicit; native prebuilt UI continues to call the generated finalization operation when appropriate.

A generated-call regression exposed a real bridge defect: `ClerkAPIError` thrown from `signIn.firstFactorVerification.error` preserved its top-level code but arrived without structured error details. The native UI therefore lost the verification message, long message and metadata. `packages/mobile-runtime/src/protocol.ts` now recognizes the source error class and serializes a single API error through the existing detail mapping, including its metadata allowlist. It preserves the rejection category and does not invent an HTTP status. HTTP response errors continue to carry their actual status. Arbitrary unknown rejection messages remain generic. The same serializer is regenerated into the Expo attached transport.

The fixture response for a transferable sign-up includes the canonical `external_account_exists` error, as required by `SignUpFuture.isTransferable`; setting the verification status alone is insufficient under the selected TypeScript contract. This is an intentional difference from the old native mock fixture. Native test fixtures retain the full verification shape, including nullable attempts, to avoid turning missing response fields into a projection failure.

## Declaration mapping

All named replacement scenarios are in `packages/mobile-runtime/test/mobile-sso.test.mjs`. They invoke generated operations through the actual bundled core and inspect FAPI requests and published state.

| Old declaration | Replacement evidence |
| --- | --- |
| `appleSignInSkipsSignUpWhenTransferIsDisabled` | `sign-in-only`: one Apple prompt, sign-in request with `oauth_token_apple` and token, no sign-up request, sign-in result, no session activation. |
| `appleSignInStartsWithSignUpAndPreservesAppleProfile` | `new-user`: first/last name and unsafe metadata preserved in sign-up body, one credential, sign-up result, no implicit finalization. |
| `appleSignInTransfersSuccessfulSignUpToExistingUser` | `existing-user`: sign-up then sign-in `transfer=true`, one Apple credential, sign-in result. The canonical fixture includes `external_account_exists`. |
| `appleSignInThrowsVerificationErrorAfterSignUpTransfersToSignIn` | `transfer-verification-error`: account-locked verification error is rejected with its code, message, long message and allowed metadata; no session activates. Newly reproduced on both native engines before the serializer fix. |
| `appleSignInFallsBackForRestrictedSignUp` | `restricted-existing` and `waitlist-existing`: both restriction codes reuse the same token for sign-in, without `transfer=true`; existing account completes. |
| `appleSignInKeepsNewUsersBlocked` | `restricted-new` and `waitlist-new`: transferable sign-in after restriction returns the original restriction error; no session activates. |
| `appleSignInDoesNotFallbackForUnrelatedSignUpError` | `unrelated-signup-error`: original `form_param_invalid` details preserved, one sign-up request, no fallback request. |

Additional cases cover an HTTP failure of the transfer request, restriction during explicit sign-up, absence of browser presentation, token exclusion from observed state, and cancellation of a pending Apple prompt by reset. Existing `apple-identity.test.mjs` checks generated `SignIn.sso` and `SignUp.sso` with explicit finalization, cancellation and unavailable hosts. Existing `AppleCredentialAuthenticationTests.appleIdentityAndPasskeysShareOneCredentialPresenter` checks actual Apple request scopes and presenter exclusivity through an injected authorization controller; it does not prove a live Apple sign-in.

## Native execution and validation

`NativeCoreContractTests/AppleSSOErrorTests.swift` adds one parameterized declaration with six scenarios. Android `NativeCoreTests/Android/AppleSSOErrorTest.kt` adds the equivalent six JUnit tests. Both invoke generated `Clerk.authenticateWithSSO` on the packaged engine with raw FAPI responses. They verify returned resource identity, one credential prompt, restricted fallback, error detail decoding, HTTP-status presence only for HTTP failures, and no implicit session activation. Android uses a fixture Apple identity capability to check the portable core contract; this does not claim an Android native Apple credential presenter.

Before the fix, the transfer-verification scenario failed on both JavaScriptCore and QuickJS because the error detail list was empty; the other five new scenarios passed. After the fix, all 489 shared embedded tests passed, including all 14 mobile SSO cases. Full packaged-core runs passed: 102 tests on macOS, 99 on iOS Simulator and 103 on Android. TypeScript checking, generated-contract checking (342 types, 1,551 members, zero unsupported shapes), and reproducibility checks passed, including the Expo attached transport. The initial native fixtures were corrected to preserve the complete verification shape and canonical transfer error before recording this before/after comparison.

Packaged JavaScript revision: `80f7c947db8f3908a85665e268f1195dc59c2ec6`. Contract SHA-256: `0f8387f260072ba6f894442b73d50afa6bda5f1205ed3c9209f5d6b1cfba16ce`. Bundle SHA-256: `b1769222a872e1fad4ce4f34cd089ac46c0ea902b8dc2a1b9327b5e6f3656cfe`. Both native manifests are byte-identical and each installed bundle matches its manifest.

The broader plan remains incomplete. Live OS authentication, actual released-app upgrades, physical-device performance and complete prebuilt UI journeys retain their release gates. This assertion audit provides deterministic behavior evidence only.
