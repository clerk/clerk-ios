# Legacy metadata access-group evidence and open migration check

This records why `SharedSessionSyncAdoptionTests.swift` remains retained. It is
not a claim that the new importer preserves every legacy storage configuration.
The source baseline is `02f98f89a19b6c079517c9aae07df7edd0e600e5`.

## What the previous major actually configured

`Sources/ClerkKit/Dependencies/DependencyContainer.swift`, in
`makeKeychainStorages`, chooses app-local storage based on adoption history:

| Previous configuration | Storage supplied to app-local consumers |
| --- | --- |
| Shared sync enabled | Configured service, omitted access group |
| Shared sync disabled, adoption marker present | Configured service, omitted access group |
| Shared sync disabled, never adopted | Configured service and configured access group |

When the configured service differs from the bundle identifier, the old
container also constructs a previous-bundle service with no explicit group.
`SharedSessionSyncAdoption.migratePrivateValueIfNeeded` searches the configured
app-local and previous-bundle sources for pending magic-link and attestation
metadata. It deliberately excludes the explicitly shared source and preserves
an existing destination value. Its validation includes expiry for magic links
and a nonempty attestation value.

Consequently, simply deleting access-group fallback from the new storage
adapter could lose metadata from a valid nonshared, never-adopted configuration.
Conversely, a previously adopted application may have old shared bytes that
were deliberately excluded from the old adoption routine.

## What the present importer and tests establish

`NativeCore/AppleCredentialStorage.swift` requires the matching previous
publishable key before importing magic-link or biometric credential metadata.
It searches the configured legacy service without a group, then uses its
explicit group fallback. It does not inspect the old adoption marker for this
branch and does not independently search a different previous-bundle service.
The current tests establish configured lookup, precedence, durable removal and
instance checks within the injected storage model.

That model treats an omitted access group as an exact dictionary key. Apple's
actual query semantics differ: an omitted group searches all the app's entitled
groups; an explicit group restricts the search. The default group for an added
item is the app's first access group. macOS access-group behavior also depends
on the data-protection/synchronizable attributes. See Apple's
[access-group reference](https://developer.apple.com/documentation/security/ksecattraccessgroup).
The old app-local query omitted the group too, so this is not sufficient
evidence of a newly introduced isolation regression.

## Still required

Use a signed host with actual app-private and shared entitlements to seed the
old service/account combinations, including duplicate accounts across groups,
and inspect the returned item's attributes. Exercise both adopted and
never-adopted histories and a changed service. Define the explicit source
selection policy from those results before claiming app attribution or adding
an automatic fallback. Verify expired flow handling and durable removal with
the selected policy.

The token-only identity and pending-clear upgrade checks are separate passing
proofs. They do not settle these metadata-source questions. Keep the old
`privateAppStateMigratesOnlyFromAppAttributedStorage` and
`ambiguousSharedPrivateAppStateIsNotMigrated` assertions as open evidence until
this check is resolved; an in-memory nil-group assertion cannot close it.
