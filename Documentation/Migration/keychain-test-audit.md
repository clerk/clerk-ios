# Keychain assertion audit

The reviewed baseline is `02f98f89a19b6c079517c9aae07df7edd0e600e5`. This audit
read `SystemKeychainTests`, `MigratingKeychainStorageTests`, `ClerkKeychainKeyTests`,
`KeychainConfigTests`, and `DependencyContainerKeychainTests`, together with the
corresponding old storage, identity, dependency-container and encoder sources.

The new tests invoke public `KeychainCredentialStorage` operations. An internal
`SecurityItemClient` supplies the same Security.framework calls in production;
tests inject an OS-call probe for failures and backend selection. The probe's
mutable state is locked. Separate process fixtures use the real Keychain in an
isolated UUID namespace and clean up only that namespace.

## Migration defects found by the review

- The old `JSONEncoder.clerkEncoder` uses `convertToSnakeCase`. Local identity
  records contain `schema_version`, `accepted_identity`, `device_token` and
  `pending_publication`. The importer and fixture now use those actual persisted
  names. It also recognizes the old unversioned identity shape supported by
  `SharedSessionLocalIdentityStore.loadRecordWithoutLocking`.
- On macOS, the old dependency container uses Data Protection Keychain first for
  a configured access group, then legacy Keychain only when that item is missing.
  The importer now preserves that precedence. An entitlement/read failure never
  triggers fallback to an older credential. Access-group whitespace is normalized
  consistently with the old configuration.
- An old `SharedSessionOwnerSlotClearRecovery` journal can outlive an interrupted
  sign-out while the accepted identity still contains its old token. A matching
  pending clear now suppresses import and writes a new durable empty record.
  Another instance's intent does not clear the current instance. Malformed or
  unsupported intents fail rather than being ignored. The old journal/shared
  slots remain available to the previous major's recovery; this SDK does not
  claim to resume shared-session synchronization.

These conclusions come from the pinned old implementations of
`SharedSessionLocalIdentityStore`, `ClerkIdentitySnapshot`,
`SharedSessionOwnerSlotClearRecovery`, `DependencyContainer.makeKeychainStorage`,
and `JSONEncoder+Ext`, not from assuming the new fixture was already accurate.

## Assertion disposition

| Old assertions | Current disposition |
| --- | --- |
| `SystemKeychainTests`: set/get, update, deletion, absent key, absent deletion | Those tests used `InMemoryKeychain`; they were not OS Keychain execution. New public-storage tests cover write/update/reconstruction/clear and retry. Real isolated process fixtures additionally cover import, reconstruction and durable clear. |
| `SystemKeychainTests`: `hasItem` and two in-memory instances being isolated | The old generic `KeychainStorage.hasItem` API and test-only dictionary are removed. New storage instances for the same scope intentionally see the same credential; separate application/key/purpose scopes are tested independently. |
| `SystemKeychainTests`: Data Protection/access-group query flags and backend-only reads | The macOS backend-precedence tests verify the actual Security query selector and resulting credential. New records are app/key-private; the old option to write arbitrary shared keys is not exposed. Live signed access-group entitlements remain a release gate. |
| `SystemKeychainTests`: entitlement guidance and unexpected-status diagnostics | Storage failures now carry shared error codes plus an `osStatus` detail. Missing-entitlement errors include Keychain Sharing/accessGroup guidance. The old localized `KeychainError` type and system-message wording are not retained. |
| `MigratingKeychainStorageTests`: fallback import, primary precedence, both missing, no fallback on primary error | Public tests verify legacy import, current-record precedence, empty scopes, and current-record read failure without old-token restoration. On macOS, Data Protection precedence/miss/error are checked separately. |
| `MigratingKeychainStorageTests.dataReturnsFallbackItemWhenMigrationWriteFails` | Intentionally changed: durable migration failure throws `secure_storage_write_failed`; it does not pretend migration succeeded. The old item remains intact so the operation can be retried. The new failure/retry test verifies this. |
| `MigratingKeychainStorageTests.setWritesOnlyToPrimary` | New writes use the new private record. Public reconstruction returns the updated value while legacy bytes remain unchanged. No second old-domain storage writer remains active. |
| `MigratingKeychainStorageTests`: deletion of primary/fallback, including primary failure | Clear now persists an empty new record instead of deleting/reimporting older state. Tests verify restart cannot resurrect the old credential, failed clear is reported, and a subsequent clear succeeds. Old bytes are preserved for migration/recovery; downgrade and shared-app behavior are not inferred from this test. |
| `MigratingKeychainStorageTests`: both `hasItem*` cases | The old existence API is removed; read/empty-record semantics are tested through the supported public storage API. |
| `ClerkKeychainKeyTests`: 19-case enumeration and raw key strings | The generic old enum is removed. The migration adapter reads only the explicitly supported previous keys; the real fixture uses the old local-identity, device-token, magic-link and biometric-metadata account names. Cache/watch/attestation/shared-transport enum membership is not a new public contract. |
| `KeychainConfigTests`: defaults, custom service, access group, combined values, property access | The old options type is removed. `LegacyKeychainConfiguration` supplies import selection; tests exercise an explicit service, normalized access group and matching key. The process fixture exercises default app-local selection. Real access-group authorization cannot be proved by property equality. |
| `DependencyContainerKeychainTests`: SystemKeychain/MigratingStorage implementation types | The dependency container is removed. These old type assertions are replaced by observed storage behavior and the macOS backend selector. |
| `DependencyContainerKeychainTests.constructionCompletesClearRecoveryBeforeReturning` | The new adapter does not run the old shared-slot recovery algorithm. Malformed journals fail import; a valid matching pending clear produces durable signed-out storage. New tests verify both outcomes before credential adoption. |
| Remaining `DependencyContainerKeychainTests`: missing shared group/owner, disabled adoption, cached bootstrap, topology, pending publication clearing | These assert old shared-session synchronization or offline-cache behavior that is explicitly unavailable. Pending identity publications with changed/empty credentials are rejected during one-time import, but this is not equivalent coverage for old convergence, slot cleanup or provisional cache hydration. Their exact declaration dispositions are recorded in the [dependency and cache audit](dependency-cache-test-audit.md). |

The new storage suite includes parameterized migration and platform-specific
backend checks; declaration counts are not a coverage percentage. Real process fixtures verify the supported
snake-case import and a pending-clear fallback. This remains a storage-format and
platform-adapter proof, not an actual released-app upgrade with a signed-in user.
`SystemKeychainTests`, `MigratingKeychainStorageTests`, `ClerkKeychainKeyTests`,
and `KeychainConfigTests` are retired after the passing replacement checks.
`DependencyContainerKeychainTests` is retired under the separate [dependency and
cache audit](dependency-cache-test-audit.md), which explicitly records removed
topology/cache contracts. Shared-session feature suites await their own audit.

The [token-only credential upgrade](token-only-credential-upgrade.md) corrects the previous overbroad cleared-state rejection using the actual old identity contract. A cleared client projection with a retained credential is distinct from a credential clear.

The [shared identity storage/event audit](shared-identity-storage-test-audit.md) supplies the assertion-level dispositions for the retired local-store, owner-slot, event and clear-recovery suites. The larger shared-session feature suites remain pending.
