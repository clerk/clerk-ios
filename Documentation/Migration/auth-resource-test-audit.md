# Sign-in and sign-up resource assertion audit

Baseline: `02f98f89a19b6c079517c9aae07df7edd0e600e5`. Every assertion in `SignInTests.swift` (27 declarations), `SignUpTests.swift` (9), and `MagicLinkServiceTests.swift` (1) was reviewed. The historical file inventory missed the multiline reload declaration in each resource suite; its 26/8 counts are not current audit totals. Parameterized cases are additional executions, not additional declarations.

These three files are retired with their removed native service collaborators after the replacement checks below pass. This does not retire the separate Auth, general core, or shared-session suites. The public API follows the TypeScript future resources. In particular, explicit code groups replace the old strategy-inferencing `verifyCode`, password authentication uses the canonical create endpoint, and sign-in/sign-up do not expose the old public `reload` method. SSO performs its reload internally. No compatibility facade or second native authentication state machine is added.

## Evidence

The embedded `auth-resource-methods.test.mjs` matrix executes fifteen generated calls: fourteen code methods and password authentication. It checks the POST endpoint, strategy, selected identifier, code/password, published resource state, and absence of implicit activation. The first-factor fixture deliberately contains a previous password verification: an explicit code method uses its own strategy. `selected-code-factors.test.mjs` separately covers default, selected and unavailable identifiers for both MFA preparations and both reset preparations.

`magic-link.test.mjs` now has four failure cases for sign-in/sign-up and storage/HTTP preparation. Saving the verifier must precede preparation; a storage failure produces no preparation request; an API failure leaves the exact saved record intact. The existing success cases check callback, email-link strategy, S256 challenge derived from the actual verifier, flow identity, expiry, completion and explicit finalization. `EmailLinkFailureTests.swift` and Android `EmailLinkFailureTest.kt` run the same four public failures on packaged JavaScriptCore and QuickJS. They also check lowered native error codes, saved flow kind/ID, verifier length, and no activated session.

Other current replacement suites are `passkey.test.mjs`, `apple-identity.test.mjs`, `mobile-sso.test.mjs`, `sso.test.mjs`, and `auth-request-continuity.test.mjs`. These exercise the actual TypeScript resources and generated protocol; old mock service calls are not duplicated in another language.

## Sign-in: all 27 declarations

| Old declaration | Assertion disposition |
| --- | --- |
| `passkeyFailureContextIdentifiesFailureStage` | The three shared first-factor failure cases retain prepare/authorization/attempt stage and error codes. Native packaged proof checks structured stage/API errors. The private wrapper and arbitrary Swift underlying-error identity are removed. |
| `publicPasskeyAuthenticationPreservesUnderlyingError` | Explicit API change: native methods throw structured `CoreError`, not the original arbitrary Swift mock-error type. Shared passkey tests preserve the code and stage; see the error audit. |
| `passkeyAuthenticationUsesSecondFactorEndpointsWhenAdvertised` | The shared passkey test checks existing-attempt second-factor prepare/attempt requests, passkey strategy and serialized credential, without recreating the sign-in. |
| `passkeySecondFactorFailureContextIdentifiesFailureStage` | Both second-factor shared failure cases preserve preparation/authorization stages and error codes. The old private error wrapper is removed. |
| `sendEmailCodeUsesSignInServicePrepareFirstFactor` | Generated `emailCode.sendCode` checks the current attempt path and email-code strategy, including selected email ID. |
| `sendEmailLinkUsesSignInServicePrepareFirstFactor` | Shared email-link success checks the current attempt, email-link strategy, email ID, configured callback, stored flow and S256 challenge. |
| `sendEmailLinkSavesPendingFlowBeforePrepare` | New embedded and native preparation-failure cases prove the flow was saved before HTTP and remains afterward. |
| `sendEmailLinkDoesNotPrepareWhenSavingPendingFlowFails` | New embedded and native storage-failure cases prove zero preparation requests and structured storage failure. Arbitrary Keychain error-type identity is replaced by the capability error code. |
| `sendPhoneCodeUsesSignInServicePrepareFirstFactor` | Generated `phoneCode.sendCode` checks the attempt path, phone-code strategy and selected phone ID. |
| `verifyCodeUsesSignInServiceAttemptFirstFactor` | Explicit `emailCode.verifyCode` checks attempt path, strategy and code. |
| `verifyCodeUsesExistingFirstFactorVerificationCodeStrategy` | Explicit `resetPasswordPhoneCode.verifyCode` checks reset-phone strategy and code. The old implicit selection from the previous verification is removed. |
| `verifyCodeThrowsWhenFirstFactorVerificationStrategyIsNotCodeBased` | The unqualified method and its local error message are removed. Callers choose a code group; the generated matrix checks the selected strategy even when previous verification is password. |
| `verifyCodeThrowsWhenFirstFactorVerificationStrategyIsMissing` | Same removed implicit method. Each generated group supplies a strategy; no native inference from an optional verification survives. |
| `authenticateWithPasswordUsesSignInServiceAttemptFirstFactor` | Future `password` POSTs `/client/sign_ins` with the supplied password and current identifier. The new generated test verifies both fields and remaining requirements. The previous attempt-first-factor endpoint/strategy assertion intentionally changes. |
| `authenticateWithIdTokenUsesSignInServiceAttemptFirstFactor` | Old raw-token instance helper is removed. Native Apple SSO uses the actual future SSO path; shared tests verify Apple token strategy/body, one host credential and no activation. Raw supported token creation remains part of generated create parameters, not this old method. |
| `sendMfaPhoneCodeUsesSignInServicePrepareSecondFactor` | Selected-factor tests check actual MFA preparation strategy, phone ID and request behavior. |
| `sendMfaEmailCodeUsesSignInServicePrepareSecondFactor` | Selected-factor tests check actual MFA preparation strategy, email ID and request behavior. |
| `verifyMfaCodeUsesSignInServiceAttemptSecondFactor` | Generated matrix checks explicit phone, TOTP and backup-code methods against the second-factor endpoint and passed code; it additionally covers email MFA. |
| `sendResetPasswordEmailCodeUsesSignInServicePrepareFirstFactor` | Selected-factor tests check reset-email strategy and selected/default identifier. |
| `handleTransferFlowCreatesSignUpWhenTransferable` | Shared `Clerk.authenticateWithSSO` test verifies transferable sign-in returns sign-up and sends `transfer` plus metadata. The private helper is removed; low-level `signIn.sso` does not silently transfer or finalize. |
| `handleTransferFlowSkipsSignUpWhenNotTransferable` | The transfer-disabled shared SSO case returns the sign-in and does not create sign-up. |
| `sendResetPasswordPhoneCodeUsesSignInServicePrepareFirstFactor` | Selected-factor tests check reset-phone strategy and selected/default identifier. |
| `resetPasswordUsesSignInServiceResetPassword` | Both reset groups' continuity tests check reset endpoint, new password and sign-out-other-sessions true/false/default. Completion does not activate a session. |
| `completeEnterpriseSSOReloadsWithNonce` | Actual future SSO roundtrip checks the current resource GET and nonce and publishes the reloaded result. The private completion helper is removed. |
| `completeEnterpriseSSOTransfersToSignUpWithoutNonce` | Shared SSO transfer test checks callback reload before optional transfer and metadata. Separate SSO nonce cases check omitted/empty nonce handling. |
| `completeEnterpriseSSODoesNotTransferWhenNotTransferable` | Transfer-disabled shared SSO preserves the reloaded sign-in without sign-up creation. |
| `reloadUsesSignInServiceGet` | Old public reload is absent from the future surface. Its nonce/nil request behavior is checked through actual SSO reconciliation; this is an explicit API removal. |

## Sign-up: all 9 declarations

| Old declaration | Assertion disposition |
| --- | --- |
| `updateUsesSignUpServiceUpdate` | Continuity tests check the current sign-up ID, first/last name and explicit legal consent, plus nested metadata and false consent. |
| `sendEmailLinkUsesSignUpServicePrepareVerification` | Shared success test checks the sign-up path, strategy, configured callback, S256 challenge and persisted sign-up flow. There is no sign-in email ID argument in this generated method. |
| `sendEmailLinkSavesPendingFlowBeforePrepare` | New embedded and native preparation-failure cases preserve the saved sign-up verifier. |
| `sendEmailLinkDoesNotPrepareWhenSavingPendingFlowFails` | New embedded and native storage-failure cases issue no preparation request. Error identity is now a structured code. |
| `sendEmailCodeUsesSignUpServicePrepareVerification` | Generated `verifications.sendEmailCode` checks path and strategy. |
| `sendPhoneCodeUsesSignUpServicePrepareVerification` | Generated `verifications.sendPhoneCode` checks path and strategy. |
| `verifyEmailCodeUsesSignUpServiceAttemptVerification` | Generated `verifications.verifyEmailCode` checks path, strategy, passed code and published completion without activation. |
| `verifyPhoneCodeUsesSignUpServiceAttemptVerification` | Generated `verifications.verifyPhoneCode` checks the corresponding phone behavior. |
| `reloadUsesSignUpServiceGet` | Old public reload is absent from the future surface. Actual SSO reconciliation checks both nonce and no-nonce requests. |

## Magic-link service: one declaration

`completeCanEstablishClientWhenTokenless` asserts only POST, a non-nil private `clerkStartupClientRefreshTakeoverID`, and that its mock handler ran. It does not assert an accepted client or persisted credential. Actual POST completion is exercised by the shared/native callback tests. The private marker belongs to the removed startup coordinator; its disposition is now covered by the completed [identity audit](identity-controller-test-audit.md), including generated tokenless-client and credential-rotation checks. Its name is not evidence of a live credential-upgrade test.

## Validation and limits

All 348 embedded tests and 181 source SignIn/SignUp tests pass. The four new email-link failure cases pass on macOS JavaScriptCore, iOS Simulator JavaScriptCore, and Android QuickJS. The bundle is unchanged because this migration adds tests and documentation only. These deterministic fixtures do not establish live mail delivery, native provider presentation, signed-in upgrades or physical-device performance. Those remain release gates, as do assertion audits of retained legacy suites.
