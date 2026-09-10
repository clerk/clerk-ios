# Watch replication assertion audit

Read all 65 test declarations, every assertion body and all six private helper
types in baseline `02f98f89a19b6c079517c9aae07df7edd0e600e5`'s
`Tests/Core/WatchSyncPayloadTests.swift` (2,168 lines). The retained file matched
the baseline bytes, SHA-256
`dfdf261c577142a5597eef88042b957e15f677f891da108900518a3366fbf6f5`.

The selected profile explicitly excludes WatchConnectivity identity replication.
`WatchSyncPayload`, its metadata/version/source types and the native coordinator
are absent from the generated SDK. The table records the exact removed contracts;
**none of these 65 declarations is claimed as passing replacement coverage**.
The test file is retired with those removed APIs after this review. The larger
shared-session/adoption suites remain for their own outstanding checks.

Reviewing durable watch clears exposed a separate migration defect. The old
`Clerk+Keychain` retains the shared adoption marker through clearing, and
`DependencyContainer` keeps the adopted local identity authoritative even when
empty. The new importer could nevertheless fall back to an old legacy token.
The [adoption-marker fix](adoption-marker-credential-upgrade.md) reproduces and
repairs that defect, preserving valid accepted credentials. It does not restore
watch replication or its watermark protocol. Token-only accepted identities are
also covered by the [earlier credential fix](token-only-credential-upgrade.md).

| Baseline declaration | Assertion and disposition |
| --- | --- |
| `watchVersionAdvancementFailsAtMaximumValue` | Watch version increment reaches Int.max and then throws exhaustion; no version counter is exported. |
| `applicationContextRoundTripsPayloadValues` | Application-context token/client/sign-in/session/date/environment round-trip; no watch payload codec is exported. |
| `applicationContextOmitsClientWhenNil` | Nil client is omitted from application context; no outgoing watch context exists. |
| `legacySignedOutPhonePayloadClearsLocalClient` | Legacy phone payload with no client clears the local client while retaining the supplied token/date; the peer adoption path is unavailable. |
| `phonePayloadAppliesAuthoritativeClientAndWinsFirstDeviceTokenSync` | Authoritative phone payload replaces the older watch token and local client/environment; source arbitration is unavailable. |
| `remoteDeviceTokenSetFencesStaleClientResponses` | Remote token replacement fences older native client-response generations; the watch transition is unavailable, distinct from core HTTP generation fencing. |
| `cachedClientHydrationDoesNotAdvanceWatchAuthVersion` | Provisional cached-client hydration does not advance watch metadata; offline client bootstrap and watch publication are unavailable. |
| `outgoingPayloadReadsDeviceTokenVersionFromMetadataRecord` | Outgoing payload uses the stored device-token version; no outgoing watch payload exists. |
| `sharedIdentityChangeUsesOneMetadataSnapshot` | Shared identity event uses exactly one metadata read; the removed coordinator's read count is not a new public contract. |
| `localClientChangeUsesOneMetadataSnapshot` | Local client event uses exactly one metadata read; the removed coordinator's read count is not a new public contract. |
| `localDeviceTokenChangeUsesOneMetadataSnapshot` | Local token event uses exactly one metadata read; the removed coordinator's read count is not a new public contract. |
| `whitespaceDeviceTokenPersistsAsClearedMetadata` | Whitespace token writes cleared watch state/version/fingerprint; watch metadata writes are unavailable. |
| `identityChangeNormalizesWhitespaceDeviceTokenBeforePublishingMetadataAndPayload` | Identity publication normalizes whitespace into a cleared outgoing token; watch publication is unavailable. |
| `watchTokenClearCannotSignOutAnActivePhone` | Watch token clear cannot sign out an active phone; the asymmetric phone/watch authority policy is unavailable. |
| `stoppedCoordinatorDropsPayloadWaitingForLocalIdentityQueue` | Stopping the coordinator drops queued identity publication without saving a token/client; no watch publication queue remains. |
| `invalidatedQueuedWatchOperationStillReleasesPublicationTracking` | Invalidated queued publication releases tracking and does not persist identity; the old publication counter and queue are removed. |
| `awaitedClearPersistsWatchTombstoneAndRejectsStalePeerIdentity` | Awaited clear advances and preserves watch tombstones and rejects stale peer identity; global clear/watch replication are unavailable. Empty adopted identity migration is separately protected by the adoption-marker fix. |
| `watchPayloadDoesNotRollBackNewerLocalStateOrFirstSyncDeviceToken` | Older watch client/date/token cannot replace newer phone state or the first-sync token; peer arbitration is unavailable. |
| `watchDeviceTokenSetDoesNotClearPhoneAuthBeforeClientReduction` | Rejected paired watch update preserves phone client/date/generation and does not leave a token; the native paired reducer is removed. |
| `rejectedWatchDeviceTokenSetPreservesPhoneDeviceToken` | Rejected watch token update preserves an existing phone credential; peer token adoption is unavailable. |
| `acceptedWatchClientSnapshotCarriesMatchingDeviceToken` | Accepted watch client carries its matching token and advances metadata/generation; the peer commit path is unavailable. |
| `staleWatchClientSnapshotDoesNotCarryDeviceToken` | Stale watch client carries no token and cannot change the date/generation; peer freshness reduction is unavailable. |
| `watchPayloadSeedsPhoneWhenNoLocalClient` | Watch snapshot seeds an empty phone client/environment/date; peer bootstrap is unavailable. |
| `watchPayloadNilClientDoesNotClearPhoneClient` | Nil watch client does not clear the phone client; peer omission semantics are unavailable. |
| `clientSnapshotWithoutPairedTokenDoesNotReuseLocalToken` | Client-only peer snapshot cannot reuse the phone's token; paired peer identity reduction is unavailable. |
| `changedTokenWithoutClientClearsOldClientBeforeRefresh` | Changed peer token clears the old client/date before refresh; direct peer token replacement is unavailable. |
| `tokenOnlyUpdateDoesNotPromoteProvisionalLegacyClient` | Token-only peer update does not promote provisional cached client and persists a cleared-client identity; peer transition/cache bootstrap are unavailable. Import of an already persisted coherent token-only identity is separately verified. |
| `adoptedIdentityWatchUpdateRefreshesHydratedToken` | Adopted watch update replaces hydrated and durable local credentials/client; live peer adoption is unavailable. Import of a valid accepted local record remains supported. |
| `rejectedTokenUpdateSuppressesPairedClient` | Rejected token version suppresses its paired client update; peer version arbitration is unavailable. |
| `payloadWithoutDeviceTokenUpdateDoesNotClearStoredToken` | Missing device-token update does not erase the stored token; peer omission semantics are unavailable. |
| `explicitDeviceTokenClearWinsOverStaleSet` | Explicit token clear rejects a lower-version set; no peer version reducer is exposed. |
| `explicitDeviceTokenClearWinsOverSameVersionNonAuthoritativeSet` | Explicit token clear rejects same-version nonauthoritative set; no peer source/version reducer is exposed. |
| `explicitDeviceTokenClearWinsOverLegacyNonAuthoritativeSet` | Explicit token clear rejects a legacy unversioned watch set; legacy peer adoption is unavailable. |
| `staleAuthSnapshotDoesNotUndoNewerExplicitClear` | Newer explicit auth clear rejects an older snapshot despite a newer date; watch auth version reduction is unavailable. |
| `legacyAuthSnapshotDoesNotUndoVersionedExplicitClear` | Versioned auth clear rejects a legacy snapshot; legacy peer version reduction is unavailable. |
| `legacyVersionlessDeviceTokenStatePayloadIsAccepted` | Legacy versionless token set/clear application contexts decode; the legacy watch codec is removed. |
| `legacyVersionlessAuthStatePayloadIsAccepted` | Legacy versionless client set/clear and date application contexts decode; the legacy watch codec is removed. |
| `legacyVersionlessPayloadAppliesAfterStateWithoutVersionMigratesToInitial` | Legacy versionless payload applies after metadata state migrates to version zero; watch metadata migration/publication is unavailable. |
| `partialUnknownOrInvalidMetadataIsRejected` | Partial/unknown/negative/fractional/overflowing/nonfinite payload metadata is rejected; no incoming watch payload decoder is exposed. |
| `tokenWriteFailureSuppressesPairedClient` | Token storage failure suppresses the paired client and preserves its date; the removed watch commit path has no replacement proof. |
| `metadataReadFailureRejectsPairedIdentityUpdate` | Watch metadata read failure rejects the paired identity; watch metadata is not an import source or active coordinator state. |
| `failedAuthMetadataSaveDoesNotAdvanceAcceptedGeneration` | Failed auth metadata promotion retains the previous accepted generation and allows retry; the native metadata writer is removed. |
| `failedSharedIdentityMetadataSaveDoesNotAdvanceAcceptedGeneration` | Failed shared-identity metadata promotion retains its generation and later advances on retry; the native watch metadata writer is removed. |
| `clearTombstoneWriteFailurePreservesExistingWatermark` | Failed tombstone update preserves the existing watermark; the old metadata transaction is unavailable. |
| `clearTombstoneReplacesCorruptMetadata` | Clear tombstone replaces corrupt JSON and sets both cleared versions; the old repair writer is unavailable. |
| `clearTombstoneReplacesMalformedLegacyStringMetadata` | Clear tombstone replaces invalid UTF-8 legacy string metadata; the old repair writer is unavailable. |
| `clearTombstoneClearsInheritedSources` | Clear tombstone removes inherited phone/watch sources; the old source watermark writer is unavailable. |
| `legacyDeviceTokenStateWithoutVersionMigratesAsVersionZero` | Legacy token state without version becomes version zero and writes a metadata record; watch metadata conversion is unavailable. |
| `legacyAuthStateWithoutVersionMigratesAsVersionZero` | Legacy auth state without version becomes version zero and writes a metadata record; watch metadata conversion is unavailable. |
| `legacyVersionWithoutStateIsCorrupt` | Legacy version without state is corrupt; the old watch metadata loader is removed. |
| `clearTombstonePropagatesMetadataReadFailure` | Metadata read failure propagates through tombstone creation; the old watch clear API is removed. |
| `pendingMetadataWatermarkRejectsRollbackAfterFinalWriteFailure` | Pending watermark rejects lower and conflicting same-version payloads after promotion failure, then permits exact retry; the watch metadata journal is unavailable. |
| `nonAuthoritativeExactRetryCanCompletePendingIdentityAfterSaveFailure` | Nonauthoritative exact retry can persist identity after a failed save without stranded pending metadata; the watch commit/retry path is unavailable. |
| `versionlessAuthoritativeAuthPayloadCannotOverrideAcceptedVersionZero` | Versionless authoritative auth cannot override accepted version zero; peer version arbitration is unavailable. |
| `acceptedAuthoritativeVersionIsIdempotentButRejectsDifferentPayload` | Identical authoritative version is idempotent while different same-version payload is rejected; peer fingerprint arbitration is unavailable. |
| `authoritativePhonePayloadResetsStaleUnknownWatchWatermark` | Phone authority can replace unknown stale watch watermarks and records phone source; peer authority migration is unavailable. |
| `authoritativePhonePayloadCanResetOnlyStaleTokenWatermark` | Phone authority can reset only a stale token watermark while advancing valid auth state; peer authority migration is unavailable. |
| `lowerAuthoritativePhonePayloadCannotRollbackAcceptedPhoneWatermark` | Lower phone version cannot roll back an accepted phone watermark; peer version arbitration is unavailable. |
| `lowerAuthoritativePhonePayloadCannotResetClearTombstone` | Lower authoritative phone payload cannot reset a clear tombstone with nil or watch source; peer tombstone arbitration is unavailable. |
| `acceptedMetadataCannotReplayAfterDurableIdentityWasCleared` | Accepted metadata cannot replay after durable identity was cleared; peer replay is unavailable. An empty adopted local identity cannot fall back to older credentials under the new migration fix. |
| `localStorageClearPersistsWatchClearMetadata` | Local storage clear creates a higher paired clear watermark and outgoing payload; global clear/watch publication are unavailable. |
| `canceledRefreshCompletionCannotClearReplacementRefreshState` | Canceled refresh cleanup cannot clear a replacement refresh task marker; the old watch refresh scheduler is removed. |
| `corruptedMetadataRejectsPairedIdentityUpdate` | Corrupt watch metadata prevents paired identity adoption; the old peer adoption path is unavailable. |
| `acceptedPayloadWithoutServerDatePreservesPreviousDate` | Accepted peer payload without a date preserves the prior date; peer date reconciliation is unavailable. |
| `tokenClearPairedWithActiveClientIsRejectedAsOneTransition` | Token clear paired with a client snapshot is rejected atomically; paired watch identity reduction is unavailable. |

## Retirement boundary

The removed helpers are `MetadataReadCountingKeychain`, `AsyncGate`,
`ReadFailingKeychain`, `FailingOnceIdentityStore`, `PromotionFailingKeychain`,
and `UpdateFailingKeychain`, plus the suite's private client/payload factories.
All were read and their names searched across current source/test targets;
there are no callers outside this file. No shared helper, runtime API or other
test is removed in this retirement.

The old whole-client snapshot, source/date/version reducer and watch journal
are not retained as a second native identity implementation. Applications
requiring phone/watch synchronization must stay on the previous major until an
explicit supported transport and migration exists. Standalone core cancellation,
credential persistence and observation tests do not establish those peer
contracts. Actual released-app upgrade and signed access-group validation remain
separate release gates.
