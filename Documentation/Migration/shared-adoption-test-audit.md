# Shared-session adoption assertion audit

All 19 declarations and helpers in `Tests/Core/SharedSessionSyncAdoptionTests.swift`
were reviewed against baseline `02f98f89a19b6c079517c9aae07df7edd0e600e5`, the
current `NativeCore/AppleCredentialStorage.swift`, and the complete
`NativeCoreContractTests/AppleCredentialStorageTests.swift`. The retained test
file's SHA-256 is
`4961f4c9078420dd796a2207747118bc4c4647f262baf1d4df270613e2538212`.

This is a retained-file audit. It does not retire the suite or claim that its
removed native types compile. The current credential importer replaces
one-time credential recovery; it does not implement the previous major's
shared publication, cached-client hydration or environment migration APIs.
Generated session state still requires canonical core startup.

| Old declaration | Current evidence and remaining work |
| --- | --- |
| `destructiveConfigurationMarksAdoptedWithoutMigratingCredentials` | `adoptedEmptyIdentityCannotRestoreAnOlderCredential` checks the previous destructive adoption marker, matching-instance isolation and reconstruction. The new durable empty record is authoritative; the old mark-adopted writer is removed. |
| `missingSharedEntitlementMarksAdoptedWithoutImportingLegacyCredentials` | The old tolerant method and provisional-hydration Boolean are removed. Current OS read errors fail connection/import with storage guidance; they do not persist a successful empty migration. macOS entitlement-error behavior is directly tested. Physical entitlement behavior remains open. |
| `partialAppLocalMigrationAllowsProvisionalHydrationWithoutSharedEntitlement` | A scoped accepted local credential imports before legacy-group fallback, including token-only records. The current suite tests those records, but not a signed local-credential/missing-shared-entitlement combination. Provisional cached-client hydration and publication-required state are unavailable. |
| `configuredAppLocalIdentityTakesPrecedenceAndMigratesEnvironment` | **Open source-selection difference:** the old adoption routine tries configured app-local, previous-bundle and shared sources in order. The current unscoped token fallback reads the configured service/group only. Existing scoped identities take precedence, but that does not prove the never-adopted source matrix. Cached environment copying is removed. |
| `privateAppStateMigratesOnlyFromAppAttributedStorage` | **Open:** valid magic-link metadata selection/expiry needs the signed source-policy check. The old test uses `attestKeyId`, not the `trustedDeviceCredentials` account exercised by the biometric probe. Neither the probe nor a dictionary's nil-group key proves preservation of this attestation assertion. |
| `ambiguousSharedPrivateAppStateIsNotMigrated` | **Open:** the old mock excludes its explicitly shared source, while real omitted-group queries can reach shared records. Simulator observations prove that distinction and show current shared-only import even with an adoption marker. Physical and valid-record checks are pending. |
| `previousBundleTokenTakesPrecedenceOverLegacySharedToken` | **Open source-selection difference:** the current configured-service/group token fallback does not search a distinct previous-bundle service. Do not claim precedence from scoped-identity tests or add fallback after an authoritative adoption marker/clear. |
| `incoherentSourceIsSkippedWithoutMixingIdentityFields` | Current import never combines independently persisted cached-client or date items with a token. The ancillary-record regression verifies they are not read. The old multi-source fallthrough order still needs the source-selection work above. |
| `malformedTokenFallsThroughToValidLaterSource` | Invalid UTF-8 and empty/whitespace-only raw tokens are rejected by the normalization regression. This does not establish the old later-source fallback: the current importer has one configured unscoped token source. |
| `malformedLegacyClientDoesNotBlockTokenOnlyAdoption` | The ancillary-record regression verifies that a valid raw token remains available despite a malformed cached client; token-only scoped identity tests independently cover the prior adopted format. Canonical startup, not a copied client, establishes session state. |
| `malformedOrNonfiniteLegacyDateDoesNotBlockTokenOnlyAdoption` | The ancillary-record regression includes malformed and nonfinite date bytes and confirms these independently stored dates are not read during token import. |
| `dateOnlySourceFallsThroughToValidLaterSource` | No date-only source can supply a credential. The current adapter ignores cached dates, but the old multiple-source fallthrough remains unproven and is not an assertion of the new test. |
| `keychainReadFailureFailsClosedInsteadOfFallingThrough` | Current-record read failures throw without importing old credentials. macOS data-protection errors also throw without falling back to the older backend; tests verify error details and retry behavior. Broader signed source combinations are pending. |
| `existingStableIdentityIsNeverReplacedDuringAdoption` | Current records precede migration. An accepted scoped old identity precedes unscoped fallback, with and without the adoption marker. Only its token is imported; preserving an old native cached Client is intentionally removed. |
| `environmentMovesAppLocallyWhileLegacySharedValuesRemainInert` | Cached environment copying is removed. The importer does not write/delete old shared source records; current durable-clear and metadata tests verify retained legacy bytes. This does not reproduce environment migration or shared-app behavior. |
| `markerIsWrittenOnlyAfterMigrationCompletes` | The old marker writer is removed. `failedMigrationWriteIsReportedAndLeavesLegacyDataAvailableForRetry` verifies that current import reports failed persistence and succeeds on retry while keeping the legacy source. |
| `tokenOnlyLegacyIdentityAdoptsAsCoherentClearedState` | The token-only regression and separate-process Keychain proof cover the valid old cleared-with-token record. Import preserves its credential for canonical refresh; it does not reimplement native cleared-client/publication state. |
| `adoptedStableIdentityDoesNotResurrectChangedLegacyStateWhenSyncIsDisabled` | Scoped accepted identities and adoption markers precede unscoped fallback. New durable clears survive reconstruction and prevent reimport. Shared-sync enable/disable configuration is unavailable. |
| `staggeredSiblingAdoptionsCanReadTheSameUntouchedLegacyIdentity` | Current import leaves legacy bytes intact. That is necessary but insufficient proof of independently signed sibling-app adoption; no sibling installation/process proof is claimed. |

## Helpers and evidence limits

The file-local factories construct removed native clients and adoption stores.
`SelectivelyFailingKeychain` and `FailingReadKeychain` inject failures into those
old stores. The shared `Tests/TestSupport/InMemoryKeychain.swift` contains the
dictionary store, set-failure store and missing-entitlement store; its SHA-256 is
`ba72860d70b13603a6a41a60b8b8476784b35cd16c5a1d8c46bf528e9c12d12b`.
It remains with this retained suite. None of these helpers can establish OS
access-group query behavior.

The [metadata evidence](legacy-metadata-access-groups.md) and
[Simulator report](evidence/keychain-migration-probe-simulator.json) remain
limited to synthetic markers. The expanded signed probe exercises metadata and
**client-token** source combinations; its
[Simulator results](legacy-metadata-access-groups.md#client-token-probe-and-configuration-history)
include the baseline call-site interpretation. Physical execution remains
pending. Preserve
authoritative local identities, adoption markers, pending clears and durable
new clears through any change. An actual old-major app upgrade with a signed-in
user is still required by the release plan.

The subsequent [metadata correction](legacy-metadata-access-groups.md#corrected-metadata-selection)
follows that call-site history and passes the OS-level Simulator probe. Valid
and expired prior email-link records are now exercised by the packaged core,
including clearing the expired record without completion HTTP. This resolves
the identified query-selection defect and that fixture-level expiry check;
physical attribution, real credential usability and App Attest continuity are
not established, so this legacy file remains retained.

## Normalization regression

The source review found that the new raw-token fallback accepted surrounding
whitespace and whitespace-only tokens, whereas the baseline adoption routine
trimmed and validated them. The new regression failed on both affected inputs
(four assertions across initial read and reconstruction). The importer now
applies the previous normalization before persisting a migrated raw token.
It leaves the original legacy bytes intact.

The complete credential-storage suite subsequently passed on macOS (20 test
declarations) and iOS Simulator (17; the three macOS backend tests are excluded
there). The added parameterized tests cover five token encodings and four
independent cached-client/date states. These checks do not exercise HTTP or
change the configured source-selection order.
