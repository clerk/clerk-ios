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
It now checks the matching old adoption marker and reads the configured legacy
service using the previous SDK's selected store: an explicit configured group
before adoption, or an omitted group after adoption. It does not independently
search a different previous-bundle service.
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

## Signed probe prepared

[KeychainMigrationProbe](../../Examples/KeychainMigrationProbe/README.md) now
links the real local SDK and records Security item attributes and adapter
selection for private/shared duplicates, insertion order, adoption history and
changed services. It also checks reconstruction, durable clears and cleanup of
its synthetic UUID-scoped records. The iOS build, strict signature verification,
resolved access-group metadata and installation on the paired physical iPhone
succeeded. The phone remains passcode locked, so physical execution and report
review are still pending; this does not resolve the source-selection policy.

## Simulator observations

The [complete report](evidence/keychain-migration-probe-simulator.json) was
produced on September 10, 2026 by iOS Simulator 26.5 (23F77), run
`B1059417-5F87-4FD1-A8FA-77A0C6131E01`. Both `magicLink` and
`biometricCredentials` purposes produced the same selection:

| Seeded metadata | Omitted-group query | Adapter imported |
| --- | --- | --- |
| Private only | Private record | Private marker |
| Shared only | Shared record | Shared marker |
| Private then shared | Both records | Private marker |
| Shared then private | Both records | Private marker |
| Adopted, shared only | Shared record | Shared marker |
| Adopted, private and shared | Both records | Private marker |
| Previous bundle service only | No configured-service record | Nothing |

Explicit group queries returned only the matching group's records. Default
insertion used the declared private group. Reconstruction preserved each
selection, removal followed by reconstruction returned nil in all 14 cases,
and exact-service fixture cleanup succeeded before the report was written.

These observations confirm that the probe executes the actual adapter and
that an omitted group is not an app-private lookup in this environment.
Private selection with duplicate accounts is only this run's observation;
it is not a supported ordering guarantee. In this initial report, the adoption
marker did not affect metadata import. The previous-bundle fixture confirms a missing
lookup, not permission to introduce one after adoption or a durable clear.

This is harness evidence, not physical entitlement or released-app upgrade
proof. The report uses invalid synthetic authentication metadata, so expiry,
real callback continuation and biometric credential usability remain outside
its scope. The retained legacy adoption tests and source-policy decision remain
open until the signed-device and valid-record checks are complete.

## Client-token probe and configuration history

The [expanded report](evidence/keychain-migration-probe-client-simulator.json)
contains 24 observations (14 metadata and 10 client-token cases), schema 2,
from Simulator run `F6BD20D2-2BEA-49AD-91BF-5779FDF9AC10` on iOS 26.5 (23F77).
All reconstruction and durable-clear checks passed, and exact-service cleanup
completed. The added attributes directly show seeded previous-bundle and
accepted-local records, including when those records were not imported.

With an explicit configured shared group, client-token selection was:

| Seeded client token | Adapter imported |
| --- | --- |
| Configured private only | Nothing |
| Configured shared only | Shared marker |
| Configured private and shared, either insertion order | Shared marker |
| Previous bundle only | Nothing |
| Previous bundle and configured shared | Shared marker |
| Configured private, previous bundle and configured shared | Shared marker |
| Adoption marker and configured shared only | Nothing |
| Adoption marker and configured private/shared | Nothing |
| Accepted local identity plus adoption marker and all three legacy sources | Accepted local marker |

These results establish the current adapter's selection in Simulator. They do
not alone establish a supported upgrade regression. The baseline
`DependencyContainer.makeKeychainStorages` invokes the old multi-source adoption
routine only while enabling shared sync. With sync disabled and no adoption
marker, the old credential and app-local stores use the configured service/group.
With an adoption marker, the old identity store is the scoped stable identity,
and metadata uses the configured service with an omitted group.

Consequently, the old first-adoption test's private/previous-bundle/shared
ordering is not the storage-read order of a never-adopted nonshared app. The
current client fallback matches that app's configured group; scoped identity
and adoption-marker precedence cover the previously adopted layout. Resuming
the old live shared-sync adoption workflow is outside the selected profile.
Adding a previous-bundle fallback indiscriminately could restore credentials
from a source that the old nonshared app was not using.

The configuration-history review exposed a metadata defect: the importer
started with an omitted-group query even for never-adopted nonshared apps whose
old store used an explicit group. The correction is described below; this
pre-fix synthetic report does not establish physical behavior. The expanded signed app
was built, signature-verified and installed, but the iPhone was still locked.

## Corrected metadata selection

The importer now follows the baseline nonshared storage selection. A matching
adoption marker equal to `2` selects an omitted-group query at the configured
service. Without that marker, metadata comes only from the configured legacy
service/group, using the previous macOS backend preference where applicable.
An absent item does not authorize searching a previous bundle or another group.
The caller must still supply the matching previous publishable key.

This preserves the previous read behavior; it does not promise that an
omitted-group query is physically private. In particular, an adopted shared-only
record can still be returned by Security.framework. Source attribution cannot
be inferred from the absence of an explicit group.

The regression first produced 24 failed assertions across both metadata
purposes: incorrect selection/reconstruction and unintended omitted-group
reads. After correction, the complete storage and packaged-core suites passed
on macOS (63 declarations) and iOS Simulator (60). The storage cases cover no
marker, a matching marker, an other-instance marker and an unknown marker,
missing configured records, reconstruction and durable removal. These injected
OS-query tests establish the chosen queries, not the operating system's group
isolation.

The packaged-core email-link test additionally checks valid and expired prior
iOS records. The valid callback completes; the expired record is cleared and
returns `no_pending_email_link` without completion or ticket HTTP. Neither
result automatically activates a session. This is core validation using fixture
HTTP and prior-format records, not a real released-app upgrade.

The [post-fix OS probe report](evidence/keychain-migration-probe-history-simulator.json),
run `C798AE1D-D103-4E77-B7F1-07A41CDA5D33` on Simulator 26.5 (23F77),
completed all 24 cases. For both metadata purposes, never-adopted private-only
records were no longer imported, and private/shared duplicates selected the
configured shared record. Adopted duplicates still selected the private record
in this run, and adopted shared-only records remained readable. Previous-bundle
only records remained unimported. All client-token selections were unchanged;
reconstruction, durable removal and fixture cleanup passed throughout.

The signed diagnostic app has been rebuilt with this correction. Its physical
runtime check remains required; none of these results closes that gate.
