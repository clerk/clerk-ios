# Preserve an empty adopted identity during upgrade

The previous major's `SharedSessionSyncAdoption` writes the UTF-8 value `2`
under `clerkSharedSessionSyncAdoptedV2` in its application/instance-scoped
identity service. `DependencyContainer.makeKeychainStorages` treats that local
identity as authoritative after adoption, including when shared sync is later
disabled and the identity is empty. `Clerk+Keychain` deliberately preserves the
marker during credential clearing so legacy shared storage cannot restore a
cleared identity. These are the actual implementations at baseline
`02f98f89a19b6c079517c9aae07df7edd0e600e5`.

The new importer previously checked for a local identity record and, when none
existed, could fall back to `clerkDeviceToken` if the caller supplied the matching
legacy publishable key. It ignored the adoption marker. An older token left in
legacy storage, or written there later by a sibling, could therefore be imported
after the app had already adopted and cleared its own identity.

The importer now honors the exact old marker in the matching identity service
before entering that fallback. It returns no credential and persists the new
durable empty record. A valid accepted local credential still takes precedence,
including a token-only identity awaiting canonical refresh. Another instance's
marker does not suppress authorized legacy migration. Existing current records
and pending-clear handling retain their precedence.

## Evidence

`AppleCredentialStorageTests.adoptedEmptyIdentityCannotRestoreAnOlderCredential`
failed on both its initial read and reconstruction before the fix. Afterward,
its matching-instance case remains empty while the other-instance case imports
the expected token. Both preserve the original marker and legacy bytes.
`adoptionMarkerPreservesItsAcceptedLocalCredential` verifies accepted present
and token-only identities remain recoverable with the marker present.

The complete storage suite passes on macOS (18 declarations) and iOS Simulator
(15 declarations). Both new declarations have two parameter cases; these
counts are not coverage percentages.

`scripts/test-native-core.sh` also passes an isolated real Keychain sequence:
one process seeds the exact marker plus an older eligible token, with no local
identity; two subsequent processes both observe no credential. The fixture now
supplies its matching legacy publishable key, so fallback is eligible and a
missing marker check would not be hidden by an unrelated instance guard. The
script's existing present-identity, pending-clear and token-only restart checks
still pass and clean up only their UUID namespaces.

This verifies credential migration and reconstruction, not phone/watch
replication or shared-owner convergence. It does not resolve the separate
[legacy metadata access-group question](legacy-metadata-access-groups.md), and
it is not a released-app physical upgrade with a signed-in user.
