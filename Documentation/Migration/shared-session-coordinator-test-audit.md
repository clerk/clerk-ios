# Shared-session coordinator assertion audit

Read all 80 declarations, every assertion body, the six private factory/wait/event
helpers and nine private helper types in baseline
`02f98f89a19b6c079517c9aae07df7edd0e600e5`'s
`Tests/Core/SharedSessionSyncTests.swift` (3,693 lines). The retained file matched
the baseline bytes and the [inventory](legacy-tests.json), SHA-256
`47f7368b0c77bf45d909e59525b4ee344851df6001581270c3c2b19c226f965e`.
Parameterized declarations retain their parameter cases; this is not a count of
passing replacement tests.

The selected profile explicitly excludes live shared-session and watch identity
replication. This review retires the file with its removed coordinator, peer
slots, frontier protocol, publication journal and notifier. **None of its 80
declarations is claimed to pass against the new SDK.** No runtime implementation,
shared test helper or test-target registration changes in this retirement.

## Portable boundaries and unresolved behavior

The [client response audit](client-response-test-audit.md) records actual shared
HTTP sequence/date/version checks and their reproduced regression. The
[identity audit](identity-controller-test-audit.md) covers stronger credential
revision fencing and credential persistence before hydration. Those outcomes do
not establish peer event generations or the removed two-phase publication.
The [client-sync middleware audit](client-sync-middleware-test-audit.md) records
the changed arbitrary-byte decoder, null-client and complete-response contracts;
[explicit credential deletion](client-credential-clear-test-audit.md) is separate
from a client snapshot disappearing. The old middleware's malformed synthetic
responses are not promises about valid generated resource results.

The [token-only upgrade proof](token-only-credential-upgrade.md) checks a cleared
client with a still-valid device credential. The
[adoption-marker proof](adoption-marker-credential-upgrade.md) prevents fallback
from an adopted empty identity to older token bytes. Neither imports UI
completion provenance or resumes a pending peer publication. The
[legacy access-group investigation](legacy-metadata-access-groups.md) remains
open in the retained adoption suite.

The [Clerk presentation audit](clerk-auth-flow-test-audit.md) separately verifies
cancellation, registration replacement, competing completions, pending sign-up,
task/enrollment sequencing, generated selection races and observable completion.
The [Clerk suite retirement](clerk-test-retirement.md) records its completed
assertion map. None of those tests establishes the removed peer protocol.
The new credential record stores no native UI completion intent; no recovered
peer completion is synthesized. Actual signed-in release upgrades, live platform
prompts and physical performance gates remain separate requirements.

| Baseline declaration | Assertion and disposition |
| --- | --- |
| `threeIndependentOwnerSlotsConvergeOnOneExactEvent` | Three independent owner slots converge on the same event/client/token; no peer slot discovery or reduction exists. |
| `initialSharedHydrationAppliesPeerClearInsteadOfStaleLocalClient` | Initial peer clear replaces stale local client/token and hydrates the peer frontier; peer bootstrap is unavailable. |
| `degradedLocalMutationPublishesAheadOfOlderSharedWinner` | A degraded local required publication advances beyond an older shared winner and preserves local identity; shared recovery is unavailable. |
| `initialSharedHydrationSeedsLocalTokenWithoutExposingLocalClient` | Local credential seeds initial peer reconciliation without exposing the provisional client; peer startup is unavailable. Import of coherent local credentials is separately verified. |
| `newlyAdoptedLegacyTokenPublishesAheadOfExistingSignedOutPeer` | New legacy-token adoption publishes beyond a signed-out peer; peer publication is unavailable, independently of supported local credential import. |
| `legacyAdoptionPublicationPreservesProvisionalClientUntilCanonicalResponse` | Both initial-hydration modes preserve provisional legacy client until canonical reconciliation; offline client bootstrap and peer publication are unavailable. |
| `ordinarySharedClearReplacesMatchingProvisionalClient` | An ordinary shared clear replaces the matching provisional client; the peer clear path and provisional cache are unavailable. |
| `competingWritesRemainDiscoverableUntilConvergence` | Competing equal-base writes remain discoverable in separate slots until convergence; no peer write arbitration is exposed. |
| `delayedResponseUsesGenerationCapturedBeforePeerPublication` | Delayed response retains its request's captured generation across peer publication; no peer frontier is exposed. Shared HTTP credential fencing is separately tested. |
| `responsePreparedBeforeAcceptedPeerFrontierIsRejected` | Responses issued before an accepted peer frontier cannot overwrite it; peer frontier rejection is unavailable. |
| `responsePreparedBeforeSameOwnerWatchUpdateIsRejected` | A response prepared before a same-owner watch update is rejected; the watch-driven generation transition is unavailable. |
| `olderResponseSequenceCannotReplaceNewerSameFrontierResponse` | Older same-frontier response sequence cannot replace a newer response; shared HTTP ordering is separately covered, without a peer frontier. |
| `failedSharedResponseStageDoesNotConsumeResponseSequence` | Failed staging does not consume a response sequence and permits retry; the old shared journal/staging API is removed. |
| `olderSequenceWithEqualServerDateAndNewerClientTimestampIsAccepted` | Older sequence with equal server date and newer client timestamp is accepted; shared HTTP date/version ordering retains this outcome, without peer publication. |
| `newerRequestFromIntermediateNetworkFrontierCanExtendResponseLineage` | A request from an intermediate accepted network frontier extends response lineage; that native lineage bookkeeping is removed. |
| `newerResponseFromSameCapturedFrontierExtendsNetworkLineage` | A newer response from the same captured frontier extends the network lineage; that native lineage bookkeeping is removed. |
| `tokenOnlyResponseResolvesIdentityWhenItsSerializedTurnBegins` | A token-only queued response resolves the current client at its serialized turn; native whole-client publication is removed. HTTP credential persistence is covered separately. |
| `canonicalActiveClientWithoutTokenThrows` | Canonical active client paired with credential clear throws before publication; the old native coordinator entry point is removed. Explicit server credential deletion has a separate current contract. |
| `peerIdentityPersistsBeforeMemoryChanges` | Peer identity persists before in-memory adoption; peer persistence is unavailable. Core credential-before-hydration checks do not prove peer storage. |
| `localPersistenceFailureRetainsPreviousInMemoryIdentity` | Local persistence failure retains previous memory; the old whole-client snapshot transaction is removed. Shared failed-credential-write checks cover the supported storage boundary. |
| `ownerSlotWriteFailureDoesNotNotifyOrApplyResponse` | Failed owner-slot write leaves pending publication without notification or accepted client; owner-slot transactions are unavailable. |
| `restartRetriesExactDurablePendingPublication` | Restart retries the exact durable pending event; no new pending peer event is persisted or replayed. Legacy pending-record import is separately scoped. |
| `sameProcessRetryRecoversIdentityWithoutReplayingOptionalPostAuthFlow` | Same-process recovery restores identity without replaying optional post-auth work; peer recovery and its completion journal are removed. |
| `sameProcessRetryDoesNotTransferCompletionToNewAuthView` | Same-process retry cannot transfer completion to a new auth view; no peer recovery completion is produced. Current registration isolation is separately tested. |
| `restartDoesNotReplayOptionalPostAuthFlow` | Restart does not replay optional post-auth work from pending publication; the new credential record contains no UI completion intent. |
| `differentSharedWinnerClearsPostAuthTargetWhenOldSessionRemainsStored` | A different shared winner supersedes awaiting or presented optional work despite the old session remaining stored; peer adoption is unavailable. Competing-session presentation remains an explicit current UI gap. |
| `staleCompletionSignalsDismissibleAuthBeforeSharedPublication` | A stale completion remains dismissible while authoritative shared publication is pending; the old native response/completion event order is unavailable. |
| `supersededResponseDoesNotTransferCompletionToReplacementAuthView` | A superseded response cannot deliver completion to a replacement auth view; peer reduction is removed. Current cancellation and registration isolation tests do not prove the old event matrix. |
| `differentSharedEventWinningSameSessionSemanticallyAcceptsCompletion` | A different winning event for the same session semantically accepts completion once; peer event/session equivalence is unavailable. Same-session UI replay has separate tests. |
| `ownPublicationChangingCurrentSessionSupersedesExistingCompletion` | Own publication selecting a different session supersedes the prior completion target; peer publication is unavailable. Generated session-switch presentation is checked separately. |
| `destructiveShutdownDiscardsPendingPublication` | Destructive shutdown discards pending publication; the removed shared coordinator's journal is not retained. |
| `acceptedCommitFailureRetainsPendingUntilExactRecovery` | Accepted-commit failure retains previous accepted identity and exact pending event until recovery; the peer two-phase commit is unavailable. |
| `pendingRecoveryNeverOverwritesNewerOwnSlot` | Pending recovery never overwrites a newer own slot; no own-slot recovery path exists. |
| `localCandidateThatLosesReductionIsNeverAccepted` | A local candidate that loses reduction is never accepted; peer candidate reduction is unavailable. |
| `futureSchemaOwnSlotDoesNotBlockPeerAdoptionOrRetainPendingIntent` | An unwritable future-schema own slot does not block peer adoption or retain pending intent; peer schema arbitration is unavailable. |
| `futureSchemaRecoveryAppliesWinnerWithoutReplayingOptionalCompletion` | Future-schema recovery applies the winner without replaying optional completion; peer recovery and completion events are unavailable. |
| `publicationNotifiesOnlyAfterAcceptedCommitAndMemoryApply` | Notification follows durable accepted commit and memory application; no shared notification is emitted. |
| `olderFailedPublicationCannotBecomePendingAfterNewerSuccess` | An older failed publication cannot restore pending intent after a newer success; the native publication journal is removed. |
| `enumerationFailureRetainsLocalIdentity` | Slot enumeration failure preserves local identity; no peer enumeration exists. |
| `emptySharedStoreDoesNotClearExistingLocalIdentity` | An empty shared store does not clear existing local identity; no shared store participates in startup. |
| `offlineColdStartHydratesSlotPublishedByTerminatedSibling` | Offline cold start hydrates a slot from a terminated sibling; peer/offline bootstrap is unavailable. |
| `initialReconciliationInstallsPeerFrontierBeforeRequestPreparation` | Initial reconciliation installs peer identity/frontier before request preparation; no peer startup barrier exists. Canonical core startup is separately checked. |
| `failedInitialReconciliationFailsPreparationOnceAndThenRetries` | Failed initial reconciliation fails preparation once and retries; the peer startup barrier is unavailable. |
| `successfulBackgroundReconciliationRepairsFailedInitialBarrier` | Successful background reconciliation repairs the failed initial barrier; no peer reconciliation scheduler exists. |
| `requestRecoversFailedReconciliationBeforeCapturingFrontier` | A request repairs failed reconciliation before capturing its frontier; no peer request frontier exists. |
| `notificationDuringFailedReconciliationSchedulesFollowupPass` | Notification during failed reconciliation schedules another pass; no shared notifier or reconciliation loop exists. |
| `requestPreparationWaitsForAlreadyQueuedSharedIdentityWork` | Request preparation waits behind already queued shared writes; no shared publication queue exists. |
| `requestPreparationCapturesAuthFlowOwnerBeforeQueuedSharedWork` | Request preparation captures auth-view ownership before waiting for queued peer work; native request ownership properties are removed. Current activation ownership has separate tests. |
| `requestCapturesOneIdentityWhenReconciliationQueuesDuringEarlierWait` | A request captures one consistent identity after earlier waits even when reconciliation is queued; no peer capture API exists. Shared HTTP request context is separately covered. |
| `concurrentSharedTokenlessRequestsShareStartupTakeoverGeneration` | Concurrent tokenless requests share the startup takeover generation; native peer takeover generation is removed. Core startup coordination is independently owned. |
| `foregroundReconciliationRecoversMissedNotification` | Foreground reconciliation recovers a missed peer notification; no peer foreground subscription exists. |
| `signOutIsPublishedAsDurableClearEvent` | Sign-out publishes a cleared client while preserving its independent device credential; live peer clear publication is unavailable. Import of this persisted token-only state is verified separately. |
| `siblingSignInAndSignOutConvergeInBothDirections` | Sibling sign-in and sign-out converge in both directions; cross-app convergence is unavailable. |
| `localClearDeletesOnlyCallingOwnersSlot` | Local clear removes only the calling owner's slot; global owner-slot clearing is unavailable. |
| `localClearPreservesObservedFrontierForNextPublication` | Local clear retains the observed frontier for a subsequent publication; no native peer frontier is retained. |
| `shutdownCanPreserveOwnSlotForSameTopologyReplacement` | Shutdown can retain the own slot for replacement with the same topology; topology replacement is unavailable. |
| `shutdownDeletionRemovesOnlyCallingOwnersSlot` | Shutdown deletion leaves other owners' slots intact; own-slot cleanup is unavailable. |
| `replicationDoesNotPostAnotherNotification` | Replication does not emit another shared notification; replication and its notification suppression are unavailable. |
| `watchPayloadPublishesOneAtomicSharedIdentityEvent` | A watch payload publishes one paired atomic identity event and replay is idempotent; the watch/shared bridge is unavailable. |
| `failedSharedWatchPublicationDiscardsPendingWatchMetadata` | Failed shared watch publication discards pending watch metadata; watch metadata staging is unavailable. |
| `watchIdentityPayloadsPublishSeriallyInArrivalOrder` | Watch identity payloads publish in arrival order; no watch publication queue remains. |
| `canceledWatchPublicationCleanupCannotEraseReplacementTask` | Canceled watch publication cleanup cannot erase replacement task tracking; the removed watch scheduler's task markers are not retained. |
| `watchPublicationAllocatesGenerationWhenCoordinatorQueueProcessesIt` | Watch publication allocates generation only when its coordinator turn runs; no peer generation allocator exists. |
| `queuedWatchPayloadDoesNotSuppressEarlierSharedIdentityChange` | Queued watch payload cannot suppress an earlier accepted shared identity's metadata; shared-to-watch metadata promotion is unavailable. |
| `watchArrivalReservesCoordinatorQueueBeforeNetworkResponse` | Watch arrival reserves queue order before a delayed network response and prevents stale client restoration; watch/network arbitration is unavailable. |
| `headerPreparationCapturesTypedFrontierAndCanonicalMarker` | Header preparation captures typed peer frontier and canonical marker, removes the internal header, and uses the accepted token even if local loading fails; native middleware properties are removed. Generated HTTP metadata is audited separately. |
| `canonicalEmptyOrMalformedResponseCannotRotateOnlyToken` | Empty/null/malformed canonical client responses cannot rotate only the token through the old middleware; the generic native byte decoder is removed. Current null-client and credential-clear behavior is audited separately, without claiming acceptance of every malformed synthetic resource. |
| `canonicalCompleteResponsePublishesTokenAndClientTogether` | A complete canonical response publishes token and client together; new storage persists only the credential before core hydration. No whole-client peer event is written. |
| `conflictingPendingEventIsAbandonedWithoutWedgingFuturePublications` | A conflicting pending event ID is abandoned, preserves maximum generation and allows a later publication; peer conflict recovery is unavailable. |
| `updateDeviceTokenPublishesClearedIdentityBeforeRefreshFailure` | Direct updateDeviceToken publishes a cleared client with the new token before refresh fails; the public global token-replacement API is unavailable. |
| `updateDeviceTokenSucceedsWhenPeerWinsWithRequestedToken` | Direct updateDeviceToken succeeds if a peer wins with the requested token; token replacement and peer arbitration are unavailable. |
| `shutdownDeletesOwnSlotAfterSuspendedPublicationAndFencesOldWork` | Shutdown waits for suspended publication, deletes its slot and fences old work without notification; shared shutdown is unavailable. Core close/cancellation checks are separate. |
| `localClearSerializesDeletionAfterSuspendedPublicationAndFencesOldWork` | Local clear serializes deletion after suspended publication and fences stale pending work; the old shared clear transaction is unavailable. |
| `localClearPreventsPendingRecoveryFromStartingANewSlotWrite` | Local clear prevents pending recovery from starting a new slot write; no peer recovery writer exists. |
| `localClearDoesNotStrandCanceledQueuedReconciliation` | Local clear resolves canceled queued reconciliation and allows later peer adoption after the barrier ends; no peer clear barrier or reconciliation queue exists. |
| `localClearBarrierRemainsActiveAfterOwnerSlotDeletion` | The clear barrier remains active after slot deletion, preventing notification-driven identity resurrection; no peer notification path exists. Durable empty credential records protect the supported local migration boundary separately. |
| `failedOwnerSlotDeletionKeepsLocalClearBarrierUntilRetrySucceeds` | Failed owner-slot deletion retains the clear barrier until retry succeeds; old global clear/slot deletion is unavailable. |
| `cleanupFailureAfterOwnerSlotDeletionReleasesLocalClearBarrier` | Cleanup failure after successful slot deletion releases the barrier and permits peer adoption; the shared cleanup barrier is unavailable. |
| `watchMetadataIsNotPromotedWhenPeerEventWinsPublication` | A peer winner prevents promotion of losing watch metadata and clears its pending marker; watch metadata promotion is unavailable. |
| `notificationNameDoesNotExposeKeychainConfiguration` | Notifier name hides raw Keychain configuration, distinguishes instances and normalizes access-group whitespace; no Darwin shared-session notifier is exported or emitted. |

## Private helper boundary

The nine private types are `TestNode`, `SharedRequestPreparationGate`,
`TestSlotBackend`, `TestBlockingSignal`, `TestOwnerSlotStore`,
`TestClearRecoveryTargets`, `SharedSessionDeleteFailingKeychain`,
`TestLocalIdentityStore`, and `TestSharedSessionSyncNotifier`. Their names were
searched across current Swift files outside this suite, with no external callers.
The backend's lock/condition gates, failure injection, staged/committed-record
classification and notifier counters were read before removal. The six private
suite methods are `makeNode`, `makeClient`, `responseContext`, `makeEvent`,
`completionEventsBeforeSentinel`, and `waitUntil`; they leave no shared API.

Applications needing sibling/watch identity convergence must remain on the
previous major until an explicitly supported transport and migration exists.
Local credential import does not provide that convergence.
