# Shared identity storage and event assertion audit

Reviewed all bodies and helpers in four baseline `02f98f89a19b6c079517c9aae07df7edd0e600e5` files: `SharedSessionIdentityEventTests.swift` (13 declarations), `SharedSessionOwnerSlotClearRecoveryTests.swift` (10), `SharedSessionLocalIdentityStoreTests.swift` (10), and `SharedSessionOwnerSlotStoreTests.swift` (14). Each file matches the [legacy inventory](legacy-tests.json). Their private spies/stores/providers have no callers outside these reviewed files.

Live shared-session event reduction, owner-slot publication and withdrawal are [unavailable](README.md#credentials-and-explicitly-unavailable-surfaces). Retiring their tests records the removal of those APIs; it does not establish equivalent cross-app synchronization or cleanup. One-time credential import remains supported and must preserve relevant isolation, read-error, interrupted-clear and no-resurrection guarantees.

This audit and the adjacent adoption review found the [token-only upgrade defect](token-only-credential-upgrade.md) in both native importers. The fixes and passing regression/process tests are recorded there. The previous cleared client state can contain a usable credential; an actual credential clear remains authoritative. `AppleCredentialStorageTests`, `CredentialUpgradeProof`, generated sign-out race tests, and current configuration tests provide the supported-operation evidence below. Source-review conclusions are not presented as live shared-app proofs.

| Old declaration | Disposition and evidence limits |
| --- | --- |
| `namespaceIncludesNormalizedPublishableKey` | The old SharedSessionNamespace value type is removed. ClerkConfiguration tests preserve trimmed test/live key distinctions and normalized origins; the migration adapter derives the previous fingerprint from a trimmed key and slash-trimmed origin. Current credential scopes keep different applications, keys and purposes separate. |
| `reducerReturnsSameWinnerForEveryPermutation` | The live shared-event reducer and permutation winner rule are unavailable. One-time credential import does not choose a winning peer event. |
| `reducerDeduplicatesReplicatedCopies` | Replicated-event deduplication and maximum-generation tracking are removed with live shared synchronization. |
| `generationTakesPriorityOverDifferingServerDates` | Cross-owner generation/date precedence is not a selected contract. |
| `serverDatePresenceBreaksEqualGenerationTie` | The shared-event dated/undated tie-break is removed. |
| `mixedDateGenerationsHaveOneWinnerForEveryPermutation` | Permutation-invariant event reduction is not performed by the new credential importer. |
| `mixedDatePresenceAtEqualGenerationHasOneWinnerForEveryPermutation` | Equal-generation server-date precedence is removed with the reducer. |
| `ownerAndEventIDBreakTiesDeterministically` | Owner/event-ID tie-breaking is not implemented in the selected profile. |
| `reducerDoesNotUseClientUpdatedAt` | The old reducer timestamp policy is unavailable. Canonical TypeScript state reconciliation is a separate owner and does not expose this reducer. |
| `signOutDoesNotAutomaticallyBeatSignIn` | The cross-owner clear-versus-present tie rule is unavailable; it must not be confused with supported in-flight sign-out credential fencing. |
| `conflictingCopiesWithSameIDAreExcludedDeterministically` | Duplicate-ID conflict exclusion and maximum-generation accounting are not performed. The importer instead rejects conflicting pending credentials for one accepted local identity. |
| `eventValidationRequiresCoherentAtomicIdentity` | The event type/generation validator is removed. Credential import requires a coherent prior accepted identity and matching pending credential; the token-only upgrade tests preserve the actual valid cleared-with-token shape and reject invalid/conflicting shapes. |
| `generationIncrementFailsClosedOnOverflow` | No native shared-event generation increment is exposed. The old UInt64 overflow error is removed with that event model. |
| `synchronousClearPersistsExactRecoveryIntentBeforeReturning` | The old clear-all/journal/owner-slot workflow is unavailable. Supported credential clear persists an empty current record; it does not begin a new old-major withdrawal intent. |
| `degradedClearRecoversOwnerSlotAfterEntitlementReturns` | Live owner-slot recovery on entitlement restoration is unavailable. Existing old journal/slot bytes remain for the previous major; the new importer suppresses matching pending clears. |
| `journalFailureLeavesIdentityAndOwnerSlotUntouched` | The new adapter does not write the old recovery journal. Current failed credential writes/clears report failure, while malformed or unreadable prior journals block import. |
| `recoveryClearsAcceptedAndPendingIdentityBeforeCoordinatorStartup` | No shared coordinator starts. A matching pending old clear prevents adopting accepted or pending credentials, and the journal remains intact rather than being reported cleaned up. |
| `recoveryUsesRecordedTopologyInsteadOfCurrentConfiguration` | The old topology-driven deletion algorithm is unavailable. Tests distinguish a matching versus other-instance journal when deciding credential import; they do not claim shared-slot deletion. |
| `disabledSyncRecoversBeforeCacheHydration` | Shared-sync configuration and offline cache hydration are removed. Import checks the prior clear journal before using an old credential; connect requires successful core startup. |
| `failedLocalIdentityDeletionKeepsSlotAndIntent` | The new adapter does not delete the old identity or slot. A new durable empty record is separate; old recovery retry behavior is not implemented. |
| `failedRecoveryPreventsCacheHydrationAndRuntimeInstallation` | The old recovery/dependency-container installation API is removed. Invalid journal/read errors still prevent credential import; there is no provisional cached-client hydration before connection succeeds. |
| `failedSlotWithdrawalLeavesClearedIdentityAndIntentForRetry` | The new SDK does not withdraw old owner slots or claim retry completion. Matching pending intents block import and remain for the previous major. |
| `futureSchemaSlotKeepsRecoveryIntentPending` | The new importer leaves the old journal and slots intact. It does not parse or delete a future-schema slot, so no new owner-slot recovery completion is claimed. |
| `legacyIdentityBlobLoadsAsAcceptedRecord` | AppleCredentialStorageTests reads the actual previous unversioned identity format. Only its credential migrates, not an old native Client or a new shared publication record. |
| `recordWrittenBeforePublicationMarkerDefaultsToSettled` | Versioned records without the publication marker import under the current storage tests. The new SDK does not track settled versus unsettled live publication work. |
| `requiredPublicationKeepsLegacyCodingKey` | The old requires_legacy_adoption_publication key is recognized in migration fixtures and left in the untouched old bytes. No replacement shared-record writer or differently named marker is introduced. |
| `requiredPublicationMarkerSurvivesStagingAndClearsOnCommit` | The stage/commit publication writer is unavailable. New token-only tests cover importing a required-publication record without attempting its publication lifecycle. |
| `stagingAndCommitReplaceOneAtomicRecord` | Atomic accepted/pending whole-client commits are removed. Current secure storage writes a credential record; live event staging and winner selection are unavailable. |
| `mismatchedCommitCannotDiscardPendingPublication` | The pending-publication commit API is removed. Import rejects a changed or empty pending credential and leaves the original legacy bytes untouched. |
| `revisionedSaveSupersedesPendingPublicationWhileOrdinarySaveRemainsStrict` | The two native save overloads and their revision/supersession policies are removed. The shared core owns approved credential commits; the adapter does not supersede old pending events. |
| `synchronousInvalidatingDeleteRejectsOlderOperationSave` | The old per-store operation revision API is removed. Generated sign-out/finalization and held credential-write tests separately prove that obsolete runtime work cannot restore credentials; direct native revisioned save is not exposed. |
| `unchangedUpdateDoesNotRewriteKeychainRecord` | The private old Keychain write-count optimization is removed with that store. The new public storage contract promises durable values, not identical OS-call counts. |
| `emptyClearPendingPublicationDoesNotDeleteKeychainRecord` | The clearPendingPublication method and delete-count assertion are removed. The importer does not delete old publication records. |
| `matchAllQueryIsLimitedToV2ServiceAndAccessGroup` | No peer-slot enumeration is performed. Import uses scoped local identities or explicitly authorized legacy credentials; old match-all query selectors are not a public contract. |
| `queriesUseNormalizedAccessGroup` | LegacyKeychainConfiguration normalizes access-group whitespace; macOS credential-storage tests verify the selected backend and group. Live shared-slot queries are removed. |
| `enumerationReturnsEveryCompatibleOwnerAndIgnoresInvalidPeers` | Multi-owner enumeration and malformed/future peer filtering are unavailable. The importer never chooses a credential from peer slots. |
| `enumerationIgnoresSameFrontendPeerFromDifferentPublishableKeyNamespace` | Peer enumeration is removed. Different-key isolation is verified for current public credential storage and matching legacy imports. |
| `saveWritesOnlyTheDerivedOwnAccount` | The shared-slot writer is removed. New writes target app/key/purpose credential records, not any peer slot. |
| `saveUpdatesKnownExistingSlotWithoutTryingToAddIt` | The old update-versus-add optimization is not retained; no shared slot is written. |
| `saveAddsKnownSlotWhenItDisappearsBeforeUpdate` | The old shared-slot update/add race is removed with the writer. |
| `addRaceDoesNotOverwriteFutureSchemaSlot` | The importer never adds or updates a shared slot, including future-schema records. This is removal of the write path, not an implementation of its retry algorithm. |
| `saveRejectsSlotForAnotherOwner` | There is no public or internal shared-slot save operation in the new profile. |
| `deleteTargetsOnlyOwnAccount` | The shared-slot deletion API is removed. New durable credential clears do not delete prior owner slots. |
| `recoveryIntentDeleteUsesRecordedServiceAccessGroupAndAccount` | The new adapter reads the prior journal to prevent credential resurrection but does not execute its recorded shared-slot deletion. The previous major retains that cleanup responsibility. |
| `futureOwnSlotDeletionReportsPreservation` | The shared-slot save/delete methods and their future-schema errors are removed. No new path rewrites or deletes these slots. |
| `futureOwnSlotDeletionReportsPreservationWhenCurrentHeaderFieldsAreAbsent` | Future owner-slot header parsing is not performed because the new adapter does not mutate owner slots. |
| `keychainReadFailureIsNotTreatedAsEmptyStorage` | The old enumeration failure type is removed. Public credential-storage tests preserve the relevant outcome: OS read errors throw and cannot cause fallback to an older credential. |

Only these four files are retired. The larger shared synchronization/adoption/watch suites, general Clerk suite and live integration suites remain pending their own final audits. No test target is disabled, and physical signed-in upgrade and entitlement gates remain open.
