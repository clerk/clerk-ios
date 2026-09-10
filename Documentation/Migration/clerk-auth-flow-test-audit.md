# Clerk auth presentation and readiness assertion audit

Reviewed the remaining 61 declarations and all assertion bodies in baseline
`02f98f89a19b6c079517c9aae07df7edd0e600e5`'s `Tests/Core/ClerkTests.swift`,
from `isLoadedReturnsFalseWhenBothNil` through `userReturnsUserForPendingSession`.
Together with the [startup/storage audit](clerk-storage-test-audit.md), all 92
declarations now have a disposition. This is not a claim of complete replacement
coverage. The old file remains retained while the explicit gaps below remain.

Authentication and session activation belong to the packaged TypeScript core.
The Swift coordinator owns only root/dismissible presentation, screen tokens,
enrollment sequencing and completion callback delivery.

| Baseline declarations | Disposition and evidence limits |
| --- | --- |
| `isLoadedReturnsFalseWhenBothNil`, `isLoadedReturnsFalseWhenOnlyEnvironmentSet`, `isLoadedReturnsFalseWhenOnlyClientSet`, `isLoadedReturnsTrueWhenBothSet`, `isLoadedBecomesTrue` | Removed mutable singleton readiness checks. `Clerk.connect` returns a connected owner asynchronously or throws; assigning client/environment independently is unavailable. Packaged connection checks exercise the replacement, not the five old nil-assignment combinations. |
| `isAuthFlowCompleteReturnsFalseWhenSignedOut`, `isAuthFlowCompleteReturnsFalseWhenSessionIsPending`, `isAuthFlowCompleteReturnsTrueWhenUserHasActiveSession`, `completedAuthenticationDoesNotGateWithoutRootRegistration` | The presentation gate still requires an active session and user. `AuthFlowCoreTests` exercises signed-out, pending and active states through packaged core HTTP; the dismissible case verifies signed-in content remains available. `anAlreadyActiveSessionDoesNotAcquireARootPresentationGate` additionally finalizes without a registration and verifies signed-in content remains available. |
| `isAuthFlowCompleteReturnsFalseWhenActiveSessionHasNoUser` | The user guard remains in `isAuthFlowComplete` and now also guards callback acceptance. The old public assignment of an active session with no user is unavailable. A malformed HTTP fixture did not reproduce that state, so this exact case is not claimed as replacement coverage. The sign-out test independently proves queued work cannot complete after identity loss. |
| `registerAuthFlowDoesNotRegisterAnExistingActiveSession`, `authFlowRegistrationIsExclusive`, `rejectedSecondRegistrationDoesNotStealInFlightWork` | Registration exclusivity and rejection of an already-active root remain in `AuthFlowCoordinator.register`. `anAlreadyActiveSessionDoesNotAcquireARootPresentationGate` verifies active-root rejection and dismissible admission. `aRejectedSecondRegistrationCannotTakeOverSuspendedFinalization` rejects another root before authentication and a dismissible registration while real activation HTTP is suspended, then proves the original owner alone completes once. The old snapshot revision equality is not a public API contract. |
| `requestsAreOwnedOnlyByTheirExplicitAuthFlowOperation` | Native request-identity capture is removed. Task-local ownership remains only around UI finalization. `aRetiredRegistrationCannotFinalizeForItsReplacement` verifies a retired owner cannot issue HTTP or activate a session and cannot cancel its replacement. It does not reproduce every old nested task-local identity assertion. |
| `dismissibleAuthFlowCompletionDoesNotGateSignedInContent`, `externalActiveSessionHoldsRootUntilAuthViewCompletes`, `acceptedCompletionBlocksRootUntilItsExactWorkCompletes` | The external activation and dismissible tests verify root blocking before reconciliation, retained completion work, callback acceptance once, and available signed-in content for dismissible presentation. This reproduced the root gate bypass and missing external active-session work before the fix. |
| `ownedHostedActivationHoldsRootUntilAuthViewCompletes`, `hostedActivationRetainsItsTargetWhileAnotherSessionIsCurrent`, `hostedActivationPromotesPresentedExternalWorkWithoutReplacingItsToken`, `hostedActivationForAnotherSessionInvalidatesPresentedWork`, `staleHostedActivationCannotMutateANewerRegistration` | Hosted portal activation is unavailable in this prerelease. Its begin/finish activation markers, target retention and stale-hosted callbacks have no passing replacement proof. Keep these assertions as evidence of the unsupported feature. |
| `supersededCompletionPreservesCurrentSessionWork`, `completionWaitsForItsSessionAcrossOrdinaryRefreshUntilActivation`, `authoritativeIdentityChangeSupersedesOwnedCompletionWhenOldSessionRemains`, `staleSameFlowRejectionPreservesAcceptedAwaitingWork`, `sameFlowRejectionYieldsToAuthoritativeIdentityChange`, `failedSessionActivationAdoptsTheAuthoritativeCurrentSession`, `finishedCompletedActivationAdoptsANewerAuthoritativeSession`, `acceptedCompletionWaitsWhileItsViableSessionHasNotBeenSelected`, `semanticRejectionIsAcceptedWhenTheCreatedSessionIsAuthoritative`, `supersededCompletionAdoptsAuthoritativeSessionForDismissal` | The old identity-update enum, semantic rejection resolver and native activation markers are removed. Generated finalization owns session activation; UI work is held during that operation and reconciled to the actual current viable session afterward. The full competing-session, rejected-activation and intermediate refresh matrix remains unverified. A source mapping is not a passing race test. |
| `presentationRetainsExactWorkAcrossRefreshAndLaterCompletion`, `finishingBiometricCredentialEnrollmentReturnsItsExactAuthWorkForCompletion`, `completingAuthFlowIsAcceptedOnceAfterBiometricCredentialEnrollment` | `repeatedCompletionPreservesAnAlreadyPresentedEnrollment` verifies the same presentation token and work survive repeated generated completion, remain root-blocking, finish once and deliver completion once. It reproduced replacement of the active presentation before the fix. A distinct later attempt ID and intervening refresh are not both reproduced by this test. |
| `replayedCompletionPreservesResolvedPostAuthWork` | `replayAfterEnrollmentFinishesDoesNotOfferEnrollmentAgain` verifies repeated generated finalization after enrollment finishes retains the same work, exposes no enrollment completion, and accepts callback delivery only once. |
| `acceptedCompletionForAnotherSessionReplacesPresentedWork`, `newerCompletionReplacesAwaitingWorkAndRejectsStaleCallbacks` | `anotherCurrentSessionInvalidatesThePresentedScreen` uses generated `setActive` to select a second server session, then rejects the old screen token and completion before reconciliation and delivers the replacement completion once afterward. `aNewAuthenticationCompletionReplacesOlderWork` now executes a second completed sign-in for either a different session while enrollment is open or the same session while work is awaiting. It verifies new attempt provenance, replaced work, rejected stale screen/completion callbacks and one completion delivery. The same-session case reproduced the mutable-attempt-ID regression documented below. |
| `sessionTaskPresentationRemainsUntilItsTokenFinishes` | `sessionTaskScreenKeepsOwnershipAfterTheCoreSessionBecomesActive` connects with a pending session, presents tasks, reloads through core HTTP to active, retains the token, rejects premature completion and accepts completion after the screen finishes. |
| `completingAuthFlowIsAcceptedOnceForAnOrdinaryFlow` | Both external-activation and retired-registration tests verify callback acceptance only once for ordinary completion. Reconciliation after accepted external completion does not offer the same session again. |
| `finishingEnrollmentForPendingSignUpAdvancesToTasksWithoutReoffering`, `taskAppearingDuringEnrollmentWaitsForEnrollmentToFinish`, `acceptedCompletionDoesNotOfferEnrollmentAfterSessionTasksBegin` | `aNewSessionTaskWaitsForEnrollmentToFinish` reloads an active session to pending while enrollment is open, verifies the task cannot replace enrollment, then finishes enrollment, presents the task without reoffering enrollment and completes after an active-session reload. Existing `AuthNavigationTests` checks route ordering. `pendingSignUpFinishesEnrollmentBeforeTasksWithoutReofferingIt` now finalizes a generated sign-up into a pending session, preserves sign-up provenance, finishes enrollment, presents tasks and completes once after server activation. `completionArrivingDuringExternalSessionTasksKeepsTheScreenAndSkipsEnrollment` promotes existing task presentation with a generated sign-in completion, preserves its token and never offers enrollment afterward. |
| `staleCompletedActivationCannotMutateANewerRegistration`, `staleRegistrationCannotMutateANewerAuthFlow` | The retired-registration test verifies stale finalization is rejected before HTTP. `cancellingAnOwnerDuringFinalizationRejectsItsLateResponse` additionally suspends the real activation HTTP capability, cancels the owner, registers a replacement and releases the late response; finalization throws cancellation, the session/user stay absent and the replacement has no adopted work. Exact old activation-handle and cross-registration start/reset combinations are not all reproduced. |
| `completedRootWorkCanReleaseOwnershipAndRearmAfterSignOut`, `terminalCurrentSessionClearsPresentedPostAuthWork` | `signOutInvalidatesACompletionWaitingForPresentation` uses generated sign-out, proves session/user are absent and rejects old completion and presentation work before and after reconciliation. `completingTheRootNotifiesObserversAndAllowsAFreshFlowAfterSignOut` additionally completes and releases the old root, signs out, registers and completes a fresh flow, rejecting the old work. `aTerminalSessionInvalidatesAnOpenEnrollmentScreen` reloads an open enrollment screen to ended, revoked and expired sessions and rejects its presentation and completion before and after reconciliation. |
| `unownedCompletionDoesNotAttachToALaterAuthView` | Unowned generated activation is adopted as external work without enrollment provenance, as exercised by the external-activation test. The old forged ownership update object is removed. |
| `authFlowGateIsObservableWhenOwnedWorkBegins` | `AuthFlowStore` is observable and coordinator revisions drive the view. The old test directly installed an active client after registering a signed-out root; that mutable API is removed. The new root deliberately stays blocked before reconciliation. `completingTheRootNotifiesObserversAndAllowsAFreshFlowAfterSignOut` directly tracks `isAuthFlowComplete` with Observation and requires a notification when the root completion releases content. This proves the replacement completion transition; it does not reproduce the removed mutable-client setup. |
| `releasingAuthFlowRegistrationClearsPendingHold` | `AuthFlowRegistration` still releases ownership on cancellation/deinitialization. `releasingTheRegistrationReleasesTheRootHold` releases the last registration reference without explicit cancellation while an active session is held behind root work, then verifies content becomes available and a dismissible flow can acquire ownership and complete once. |
| `handleReturnsFalseForUnrecognizedURL`, `handleReturnsTrueForMagicLinkCallback`, `handleDeduplicatesConcurrentMagicLinkCallbacks`, `handleReturnsFalseForMismatchedMagicLinkCallbackOrigin` | See the [callback audit](callback-test-audit.md) for origin matching, persisted verifier redemption, concurrent deduplication and ticket handling. Callback processing is navigation-free; callers explicitly finalize completed attempts. The old implicit session activation and native service-call counts are intentionally changed. |
| `shouldShowDevelopmentModeWarningReturnsFalseWhenEnvironmentIsMissing`, `shouldShowDevelopmentModeWarningReturnsFalseWhenFlagIsDisabled`, `shouldShowDevelopmentModeWarningReturnsFalseForProductionEnvironment`, `shouldShowDevelopmentModeWarningReturnsTrueForDevelopmentEnvironment`, `shouldShowDevelopmentModeWarningReturnsTrueForUnknownNonProductionEnvironment` | See the [environment audit](environment-test-audit.md) for development-warning configuration, production/unknown instance modes and partial settings. Public mutable environment assignment is removed; current UI reads the projected settings. |
| `sessionReturnsPendingSession`, `userReturnsUserForPendingSession` | Pending sessions and their users remain available through the generated core. The packaged task-screen test starts from that pending client and advances it to active; the [session-selection audit](session-utility-test-audit.md) records canonical selection and terminal-state limits. |

## Reproduced regressions and current proof

The new `Tests/UI/AuthFlowCoreTests.swift` uses the real packaged JavaScriptCore
bundle and generated `Clerk.connect`, SSO, finalization, reload and sign-out
operations. Only OS/HTTP/storage capabilities are fixtures. It does not assign
public resource state or emulate authentication in Swift.

The first run reproduced three failures: externally activated root content could
become complete before callback delivery; external active sessions did not create
presentation work; replayed completion replaced an enrollment screen's token.
The coordinator now retains a presentation completion marker for the delivered
session, adopts external active sessions, and preserves current same-session
presentation work across repeated finalization. Losing the viable session resets
the marker. Generated finalization still executes on every call.

Six packaged-core presentation tests and both complete UI targets passed:
iOS has 145 tests in 26 suites; macOS has 134 tests in 22 suites. The macOS
run logged contacts persistence XPC error 4097 and `Failed to create NSXPCConnection`;
the iOS run logged `clip: empty path` and unbalanced appearance transitions in
the existing footer tests. These diagnostics did not fail the targets.
These tests do not prove live SSO, system prompts, physical
upgrade continuity, or every retained legacy race. The old non-UI target still
contains tests against the removed API; this change does not hide or delete it.

## Additional packaged race checks

Four additional tests cover replay after enrollment finishes, a generated
session switch during presentation, a task appearing during enrollment, and
owner cancellation while activation HTTP is suspended. All ten presentation
tests pass on both iOS and macOS. These exercise the previously fixed coordinator and shared
runtime; no production change was required for these four cases.

The session-switch fixture first reloads the client with both sessions and then
calls generated `setActive`. A server `last_active_session_id` change alone does
not replace the already selected session. The cancellation fixture deliberately
releases its suspended HTTP response after cancellation, checking the actual
late-response boundary rather than only cancelling before a request starts.

## Packaged ownership, observation and terminal-session checks

At this checkpoint the suite had 16 test declarations, all passing on macOS and the iOS
Simulator (1.883 and 1.631 seconds respectively on September 10, 2026).
The terminal-session declaration executes three cases: ended, revoked and
expired. Five new declarations cover active-root rejection, exclusive
ownership while activation HTTP is suspended, observable completion and
rearming after sign-out, terminal-session screen invalidation, and registration
deinitialization. The deinitialization check waits at most two seconds for the
public presentation hold to release; it does not depend on a particular task
or timer identity.

The initial rearming check reported `CancellationError()` because the fixture
server continued returning its signed-out client on the second login. The
fixture now exposes the next authenticated client for that SSO callback.
No production behavior changed for these five checks. The second flow uses the
fixture's existing session identifier; it proves fresh presentation ownership,
not creation of a distinct backend session. macOS again logged CoreData
`Failed to create NSXPCConnection` and service connection error 4097 without
failing the tests.

The old file remains retained for the explicitly unresolved competing-session
and legacy hosted-auth assertions. These in-process checks do not replace live
browser/prompt or physical released-app upgrade testing.

## Captured attempt identity and pending sign-up checks

A second completed sign-in for the same session reproduced stale presentation
work through real packaged JavaScriptCore. The generated `SignIn` object is
stable while its underlying attempt ID changes. The coordinator previously
computed its target's ID from that mutable resource, so both the old target and
new completion appeared to have the new attempt ID. It retained the old work
and accepted an obsolete enrollment callback. The initial run reported four
failed expectations in the same-session case; the different-session case passed.

`AuthFlowCoordinator.Target` now captures the attempt ID when completion work is
created or an external screen gains completion provenance. A genuine replay of
the same attempt keeps its work; a new attempt awaiting presentation replaces it.
Authentication, session selection and generated resource state still execute in
TypeScript. No bundle or binding contract changed.

Three new declarations cover that two-case completion matrix, pending sign-up
through enrollment/tasks, and completion arriving after an external task screen
has begun. The initial pending sign-up fixture supplied only an attempt result
and omitted its created session from the client envelope. Unlike sign-in's
finalize implementation, sign-up finalize does not reload an absent session.
That fixture returned `CancellationError()` with no selected session and no touch
request. The corrected fixture includes the complete sign-up/client envelope;
no shared runtime change was made for that fixture error.

The full macOS UI target passes 154 tests in 23 suites, including all 19
`AuthFlowCoreTests` declarations (the completion matrix has two parameter cases
and terminal-session invalidation has three). The run took 3.450 seconds.
The full iOS Simulator target passes 165 tests in 27 suites in 2.574 seconds,
including the same 19 presentation declarations (2.573 seconds).
The Swift formatter reported an unwritable cache under Library/Caches but
formatted the source successfully. Existing macOS Contacts/CoreData XPC
diagnostics did not fail the target.

The retained legacy file still tracks the broader rejected-activation and
intermediate-refresh matrix, as well as removed hosted-portal activation
contracts. These checks do not establish physical browser/biometric prompts,
real backend authentication or released-app upgrade continuity.
