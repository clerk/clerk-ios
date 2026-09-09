# Clerk startup and storage assertion audit

Reviewed the first 31 test declarations in baseline
`02f98f89a19b6c079517c9aae07df7edd0e600e5`'s `Tests/Core/ClerkTests.swift`,
through `biometricCredentialInstallationMarkerPreservesConfigurationBoundaries`.
All assertion bodies in this range were read. The remaining 61 declarations,
starting with `isLoadedReturnsFalseWhenBothNil`, still require their own audit.
The file remains retained; this document does not authorize deleting it.

| Baseline test or group | Disposition and limits |
| --- | --- |
| `callbackContinuationReturnsPendingAuthResult` | Removed native callback enum. The generated attempt retains pending requirements; callback routing has a separate callback assertion audit. Assigning the old enum itself has no replacement. |
| `isolatedConfigurationInstallsPersistenceBeforeStartup` | Native connection installs its storage capabilities before core initialization. Packaged credential tests verify restored credentials permit a headerless startup response. The three old keychain collaborator identity assertions are removed. |
| `clearAllKeychainItemsDeletesStoredDataAndPreservesAdoptionMarker` | No global all-keychain-items API exists. Scoped storage uses durable empty records; old adoption/watch/cache/attestation keys are not globally erased. This is a migration difference, not equivalent coverage. |
| `clearAllKeychainItemsClearsAtomicLiveIdentity`, `synchronousClearDeletesAtomicIdentityBeforeReturning` | Removed whole-client persistence and synchronous global clear. Generated attempt reset is not an identity wipe. These assertions have no same-call replacement. |
| `sharedConfigurationHydratesProvisionalLegacyClientAfterAdoption`, `provisionalLegacyClientIsExcludedFromRequestAndWatchIdentity`, `acceptedClientResponsePromotesProvisionalLegacyClient`, `sharedConfigurationDoesNotHydrateLegacyClientAfterAdoptionWindow` | Provisional cached-client hydration is unavailable. Startup imports a credential and obtains the client through core HTTP; old cached client publication/promotion and watch exclusion are not reproduced. |
| `sharedActivationHydratesPeerIdentitySynchronously` | Live peer-owner reconciliation is unavailable. Credential import does not establish peer hydration. |
| `missingSharedEntitlementDiscardsPendingPublicationAndUsesDurableLocalIdentity` | The importer rejects an ambiguous pending identity publication. It does not clear the old publication, recover shared entitlement failure, or resume publication. The old durable-local fallback is not equivalent to this safe signed-out fallback. |
| `synchronousClearCannotBeUndoneByPreviouslySuspendedIdentitySave`, `awaitedClearCannotBeUndoneByPreviouslySuspendedIdentitySave`, `awaitedClearDrainsSuspendedCacheWriterBeforeFinalDeletion` | Removed atomic-client/cache writers and global clear APIs. Shared transport invalidation serializes credential writes/removal and fences stale responses, but those checks do not replace a public all-storage clear. |
| `synchronousClearRemainsCallableFromAsyncCodeAndOverlappingCallsCoalesce` | Removed synchronous API, task handle and coalescing revision. No same-call contract exists. |
| `strictReconfigurationClearPreservesNewWatchTombstone` | Live watch state and destructive mutable reconfiguration are unavailable. New-instance scoping is covered separately; it does not publish a watch tombstone. |
| `awaitedClearReportsAtomicIdentityDeletionFailure`, `awaitedClearAcceptsSuccessfulAtomicIdentityDeletionRetry` | Public scoped storage reports failed durable writes and permits a subsequent explicit retry. The old automatic deletion retry and atomic identity record are removed. |
| `awaitedClearWithdrawsOwnerSlotBeforeReturning`, `awaitedClearKeepsPublicationBlockedUntilRecoveryIntentIsRemoved`, `awaitedClearKeepsRecoveryIntentWhenAtomicIdentityDeletionFailsTwice` | Shared owner-slot cleanup/recovery is unavailable. The importer detects the old pending clear journal and suppresses stale credential import, but leaves old slot/journal cleanup to the previous major. |
| `adoptedWatchTransitionFencesOlderQueuedNetworkResponse` | Watch adoption is unavailable. Core generation, credential-rotation and response-date fences have direct tests; none proves this unavailable watch transition. |
| `clearAllKeychainItemsHandlesMissingKeysGracefully`, `clearAllKeychainItemsWorksWhenClerkNotConfigured`, `clearAllKeychainItemsDoesNotThrow` | Removed global clear. Scoped `remove` is idempotent and can throw on persistence failure. The old unconfigured-named test actually configured a mock and did not prove the unconfigured path; the nonthrowing-named test did not inject a failure. |
| `clearAllKeychainItemsPreservesBiometricCredentialMetadataWhenCredentialCleanupFails`, `clearAllKeychainItemsStrictlyPreservesBiometricCredentialMetadataWhenCredentialCleanupFails` | Removed global clear. Core account-specific biometric cleanup retains a failed key deletion for retry. These old tests inject a metadata read failure into global cleanup; that exact operation is not available. |
| `configureClearsCurrentAppBiometricCredentialsWhenInstallMarkerIsMissing`, `configureKeepsBiometricCredentialsWhenLegacyInstallMarkerExists`, `configureUsesAppScopedBiometricCredentialInstallationMarkers`, `biometricCredentialInstallationMarkerPreservesConfigurationBoundaries` | Unresolved behavior gap: current Apple capabilities do not inspect the old installation markers or clear surviving biometric keys on reinstall. App/publishable-key storage scoping alone does not prove reinstall cleanup or marker compatibility. Keep these assertions and resolve this before claiming biometric upgrade/reinstall continuity. |

## Metadata format verification

Apple baseline `BiometricCredentialLocalStore` uses its own default-key encoder
with millisecond dates and an explicit `userId` coding key. It does not use the
general snake_case Clerk encoder. A new public Keychain adapter test imports that
actual record shape only with an explicit matching legacy instance, verifies
reconstruction and a durable clear, and preserves the original legacy bytes.
It uses the injected Security item boundary; it does not claim an enrolled key
or physical app upgrade.

The same investigation found an Android defect: its old store does use the
snake_case encoder and omits the default policy. TypeScript pin `ad16bc0d65`
normalizes that legacy Android shape. Android's encrypted-storage/packaged-core
test reproduced the lost credential before the fix. Apple records continue
through the existing camelCase path.
