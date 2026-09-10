# Legacy dependency and offline-cache assertion audit

Reviewed all bodies and helpers in `DependencyContainerKeychainTests.swift` (9 declarations) and `CacheManagerTests.swift` (14) at baseline `02f98f89a19b6c079517c9aae07df7edd0e600e5`. Their bytes match the [legacy inventory](legacy-tests.json). The cache coordinator and wait helpers are test-only collaborators with no remaining references outside the retired cache suite.

The [selected profile](README.md#credentials-and-explicitly-unavailable-surfaces) explicitly omits live shared-session synchronization and persistent offline resource-cache bootstrap. Retirement of those assertions records a removed major-version contract; it does not claim feature equivalence. Applications needing these features must remain on the previous major. Credential continuity is distinct and uses the [Keychain adapter proof](keychain-test-audit.md).

Current evidence is `NativeCore/AppleCredentialStorage.swift`, `NativeCoreContractTests/AppleCredentialStorageTests.swift`, and the isolated real-Keychain `NativeCoreTests/CredentialUpgradeProof.swift`. The storage tests exercise public operations through an OS-call probe; the process fixture exercises the real Keychain. Neither proves a signed-in released-app upgrade or live shared-app convergence.

| Old declaration | Disposition |
| --- | --- |
| `sharedSessionSyncFailsClosedWithoutAccessGroup` | The shared-session enable option is removed; live shared synchronization is unavailable. There is no supported configuration to silently enable it without an access group. |
| `sharedSessionSyncFailsClosedWithoutOwnerIdentifier` | The shared owner option is removed. The new app-owned core does not register a shared-session owner. |
| `keychainStorageWithoutAccessGroupUsesSystemKeychain` | The private DependencyContainer/SystemKeychain types are gone. KeychainCredentialStorage uses Security.framework; public read/write/reconstruction and isolated process fixtures exercise its behavior. |
| `disabledPersistentAdoptionDoesNotInstallLiveClearRecovery` | The override and recovery coordinator are removed. The importer checks a prior clear journal, but never installs the old live recovery service. |
| `constructionCompletesClearRecoveryBeforeReturning` | Malformed prior clear journals fail import. A valid matching intent suppresses import; another instance remains unaffected. AppleCredentialStorageTests verifies these outcomes and retention of journal bytes. This is not old shared-slot cleanup. |
| `keychainStorageWithAccessGroupUsesMigratingStorage` | Private type identity is removed. The macOS storage tests check Data Protection precedence, fallback only for missing items, and surfaced entitlement failures. |
| `disabledConfigurationWithoutAdoptionMarkerKeepsLegacyPersistenceBoundary` | The old writer/cache boundary is removed. New writes are scoped to app, key, and purpose; importing an unscoped token requires a matching explicit key. Tests verify reconstruction and unchanged legacy bytes. Client/environment/server-date cache bootstrap is unavailable. |
| `sharedConfigurationBuildsExactRecoveryTopology` | Shared-slot service/account/owner topology is not in this profile. LegacyKeychainConfiguration normalizes the import access group; this does not establish old shared transport topology. |
| `constructingDisabledTransportDoesNotClearPendingPublication` | The new importer neither stages nor discards the old pending publication. Tests reject a changed/cleared pending credential and accept the same credential; live publication convergence is unavailable. |
| `testSaveClient` | Persisting complete client snapshots is removed. Only approved credentials and purpose-specific recovery metadata are persisted. |
| `testSaveEnvironment` | Persistent environment snapshot caching is unavailable; startup obtains current environment state through the core. |
| `testDeleteClient` | The old cachedClient deletion API is removed. Supported client-credential clear writes a durable empty record; reconstruction tests prove no legacy reimport. Deleting old cachedClient bytes is not promised. |
| `loadCachedClient` | Offline client hydration from cachedClient is unavailable; credential import is followed by server reconciliation. |
| `atomicIdentityStorePreventsLegacyClientFallbackWhenEmpty` | No cached-client fallback is present. Storage tests separately prove current empty records and conflicting pending identities cannot restore an old credential. |
| `loadCachedDataCanSkipAtomicIdentityHydration` | The hydrateIdentity flag and separate cached environment bootstrap are removed. |
| `provisionalLegacyClientHydrationUsesExplicitSources` | Provisional cached-client presentation is unavailable. Successful connection requires current core startup; no legacy server date is exposed as fresh state. |
| `provisionalLegacyClientHydrationRequiresTokenInSameSource` | Provisional presentation is unavailable. The importer independently requires a present accepted identity with client data and a nonempty token, or explicitly authorizes an unscoped token by matching key. |
| `loadCachedEnvironment` | The persistent cachedEnvironment read path is removed. |
| `doesNotLoadClientWhenAlreadyExists` | The mock coordinator callback count belongs to the removed offline cache. It is not a new native state-delivery contract. |
| `doesNotLoadEnvironmentWhenAlreadyExists` | The mock coordinator callback count belongs to the removed offline cache. |
| `shutdownIgnoresFuturePersistenceRequests` | The cached-environment background writer is removed. This assertion does not verify credential-generation fencing; those supported outcomes have separate persistence/race tests. |
| `shutdownAndDrainCompletesPendingPersistenceRequests` | The cache-writer shutdownAndDrain API is removed. The new core awaits credential persistence at its commit boundary; it does not drain an environment-cache queue. |
| `handlesMissingCachedData` | No offline cache is read. Empty credential scopes are covered by public storage tests; a connection still requires successful startup HTTP. |

Only these two reviewed files are retired. Shared-session feature suites and live integration tests remain pending their own audits; the default legacy test target is not disabled.
