# Hosted portal assertion audit

All bodies and helpers in `HostedAuthTests.swift` (23 declarations), `HostedAuthServiceTests.swift` (4), and `HostedAuthPersistenceTests.swift` (5) were read against baseline `02f98f89a19b6c079517c9aae07df7edd0e600e5`; each file matches the [legacy inventory](legacy-tests.json). Parameterized atomic/shared persistence modes are not counted as extra declarations.

`startHostedAuth` and the hosted-portal redemption protocol are [explicitly unavailable](README.md#credentials-and-explicitly-unavailable-surfaces). These test retirements record a removed feature. They do not close hosted-portal compatibility, signed-in upgrade, or live shared-session gates. Applications requiring hosted portal authentication must remain on the previous major.

The supported future `signIn.sso` / `signUp.sso` methods retain the full browser/callback/cancellation/nonce/reconciliation seam in TypeScript and return the canonical flow outcome. Low-level finalization remains explicit. Existing `packages/mobile-runtime/test/sso.test.mjs` and `protocol.test.mjs` check real future-facade execution, remaining requirements, cancellation, unrelated callbacks, reset, finalization and sign-out fencing. Those checks are separate contracts and are not substituted for this portal protocol. No runtime code or SSO behavior changes in this retirement.

| Old declaration | Disposition and limit |
| --- | --- |
| `modeUsesHostedAuthProtocolValues` | The hosted-portal sign-in/sign-up mode enum is removed. |
| `hostedAuthResourceRequiresExpectedObjectAndWebOrigin` | The hosted_auth resource decoder and HTTPS portal URL validator are removed; the new SSO host has its own URL validation and no HostedAuthResource. |
| `generatedStateIsRandomAndNonEmpty` | The native HostedAuthState generator is removed. This random-state assertion is specific to that protocol; SSO nonce/state ownership follows canonical TypeScript and platform capabilities. |
| `redirectMatchesSchemeAuthorityPortAndPath` | The HostedAuthRedirect matcher is removed. Current supported callbacks have independent host validation; this is not proof of portal compatibility. |
| `redirectInitRejectsNonCustomSchemeAndMalformedValues` | The old portal constructor only accepted custom schemes. Its exact rejection list is removed; supported new HTTPS callbacks depend on platform version and associated links. |
| `tripleSlashRedirectRejectsInjectedOrMissingAuthority` | The portal matcher and exact triple-slash policy are removed. New callback allowlisting has separate tests, not a hosted-portal replacement. |
| `callbackRequiresExactStateNonceAndCreatedSession` | The portal callback state, rotating_token_nonce, and created_session_id tuple is removed. Future SSO reconciles its own attempt; it does not accept this tuple as an automatic session-activation instruction. |
| `callbackStateValidationRejectsMissingDuplicatedAndMismatchedState` | The portal parser and exact error message are removed; no supported startHostedAuth operation consumes these callbacks. |
| `successRedeemsUpdatesClientAndActivatesOnlyCallbackSession` | The native portal create/browser/redeem/PKCE/automatic-activation pipeline is unavailable, including returned Session and server-date cache. Generated low-level SSO does not silently finalize. |
| `overlappingStartIsRejectedBeforeCreatingAnotherTransfer` | The native portal in-flight gate and create-count assertion are removed; no second hosted transfer can be created through this profile. |
| `cancellationPropagatesWithoutRedeemingOrActivating` | The hosted operation is removed. Supported SSO cancellation is separately checked without reconciliation or implicit activation; it is not a portal redemption proof. |
| `signedOutCreateRefreshesClientAndRetriesOnceWithSameParams` | The portal-specific signed_out refresh/retry policy, skipClientId flag, and frozen create parameters are removed. No retry coordinator is ported to native. |
| `secondSignedOutCreateIsNotRetried` | The portal create retry-count limit is unavailable. |
| `nonSignedOutCreateErrorIsNotRetried` | The portal create error/retry policy is unavailable. |
| `signedOutRedeemErrorIsNotRetriedOrReconciled` | The portal redeem endpoint policy is unavailable; no replay of its nonce is introduced. |
| `missingCallbackSessionDoesNotApplyClientOrActivateAnotherSession` | The portal created_session_id selection gate is removed. Future finalization uses the canonical attempt/session state, not this callback field. |
| `explicitClearRedeemResponseClearsIdentityWithoutActivating` | The portal reducer is removed. Shared clear-marker handling and durable credential clear have separate generated-client tests; this fixture does not become a supported portal response. |
| `clientChangeDuringActivationDoesNotReturnStaleSession` | The portal automatic-activation return contract is removed. Supported generated finalization has independent sign-out/state-revision fencing proofs. |
| `failedFlowReleasesInFlightGateForSubsequentAttempts` | The native portal in-flight gate and retry-after-cancel contract are removed. |
| `reconfigurationWhileBrowserOpenFailsBeforeRedeem` | The mutable global reconfiguration/portal protocol is removed. New application owners close and reconnect; supported browser effects follow runtime lifetime. |
| `generationChangeWhileBrowserOpenDiscardsRedeemedClient` | The portal client-response-generation gate is removed. The test actually requires no redeem call after the fence, not merely filtered UI observation. |
| `generationChangeDuringRedeemDiscardsResponseWithoutActivating` | The portal reducer is removed. Its redeemed-client fixture and exact error are not a supported response path; generated finalization races are checked independently. |
| `nilRedirectUrlFallsBackToConfiguredRedirectUrl` | The portal per-call optional override and old RedirectConfig fallback are removed. New owner configuration supplies the callback URL for supported operations. |
| `createUsesHostedAuthPostRequestShape` | POST /client/hosted_auth, redirect_url/code_challenge/state/mode fields, sync/log flags, and exact _is_native=true query are removed with this endpoint. Canonical native request metadata follows its own tested contract. |
| `createOmitsModeWhenNotProvided` | The native HostedAuthCreateParams encoder is removed. |
| `redeemUsesPhysicalPostBodyAndDisablesAutomaticClientSync` | The hosted physical POST /client with _method=GET, rotating_token_nonce/code_verifier and deferred ClientSyncResponseContext is removed. No new portal request is sent. |
| `redeemPreservesAuthoritativeDeviceTokenClear` | The portal-specific deferred clear context is removed. The shared client-clear audit covers supported requests, not this portal endpoint. |
| `redeemPersistsIdentityBeforeActivation` | Both atomic and shared-slot portal modes are unavailable. The old assertions persist whole client/server-date/owner-slot records before automatic activation; new credential persistence before hydration is a narrower, separate contract. |
| `redeemPersistenceFailureDoesNotExposeOrActivateIdentity` | The portal atomic/shared write path and staged publication retry record are removed. Supported storage failures still propagate through the shared core, without claiming old shared-slot rollback or retry semantics. |
| `missingCallbackSessionDoesNotMutatePersistedIdentity` | Portal session selection and both old stores are removed. There is no import path accepting this portal response as a selected session. |
| `generationChangeBeforeRedeemSkipsRedeemAndPreservesIdentity` | The portal generation fence and atomic/shared storage modes are removed. |
| `sharedFrontierAdvanceDuringRedeemRejectsResponseWithoutActivating` | Live shared-session frontier coordination is unavailable. The one-time legacy credential importer does not replace concurrent owner-slot convergence. |

The three reviewed files and their self-contained helpers are retired together. The legacy inventory retains pinned source links and names. The broader Clerk/core and shared-session suites still await their own final dispositions; no test target is disabled.
