# Signed Keychain migration probe

This standalone diagnostic app links the current local `ClerkKit` package. It
uses the real `KeychainCredentialStorage` adapter and Security.framework to
observe omitted-group queries, explicit private/shared queries and metadata
migration. It does not connect to a real Clerk instance or open an auth prompt.

Each launch allocates UUID-scoped services containing synthetic UTF-8 markers.
For both magic-link and biometric-metadata purposes it checks private-only,
shared-only, duplicate accounts in both insertion orders, adopted histories,
and a changed-service/previous-bundle case. Ten client-token cases additionally
cover previous-bundle/shared combinations and an accepted local identity with
an adoption marker. The report contains 24 observations and records the
previous-bundle and accepted-local item attributes separately. It records returned item attributes,
which marker the actual adapter imported, reconstruction and durable removal.
All cleanup is restricted to exact services created by that run. A successful
report is written only after cleanup succeeds.

The markers are deliberately not valid authentication records. This probe
answers source-selection and OS-query questions; it does not establish expired
flow validation, biometric key continuity, real login, cross-process concurrency,
or a released-app upgrade. Duplicate query results are observations, not a
promise about Security.framework ordering.

## Build and run

Use a development team with a locally installed profile covering the device and
both Keychain access groups. The app's first group is its private group; the
second is the probe's shared group. The team prefix is expanded by signing and
also written into the probe's Info.plist. Do not supply a manual provisioning
profile globally: that also affects Swift package resource bundles. Automatic
signing can select an existing managed wildcard profile without requesting
provisioning updates.

From the repository root, with `CLERK_PROBE_TEAM` and `CLERK_PROBE_DEVICE` set:

```sh
xcodebuild build -project Examples/KeychainMigrationProbe/KeychainMigrationProbe.xcodeproj -scheme KeychainMigrationProbe -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /tmp/clerk-keychain-probe DEVELOPMENT_TEAM="$CLERK_PROBE_TEAM"
codesign --verify --deep --strict /tmp/clerk-keychain-probe/Build/Products/Debug-iphoneos/KeychainMigrationProbe.app
xcrun devicectl device install app --device "$CLERK_PROBE_DEVICE" /tmp/clerk-keychain-probe/Build/Products/Debug-iphoneos/KeychainMigrationProbe.app
```

Unlock the device normally before launching. The probe runs once per process
and displays its JSON report. Then copy that report from its own data container:

```sh
xcrun devicectl device process launch --device "$CLERK_PROBE_DEVICE" com.clerk.nativecore.keychain-migration-probe
xcrun devicectl device copy from --device "$CLERK_PROBE_DEVICE" --domain-type appDataContainer --domain-identifier com.clerk.nativecore.keychain-migration-probe --source Documents/keychain-migration-probe.json --destination /tmp/keychain-migration-probe.json
```

A Simulator run can check the probe's mechanics but does not establish physical
signing/entitlement behavior. Inspect physical report attributes before choosing
an automatic metadata-source policy.

To check the harness on an already booted Simulator, set `CLERK_PROBE_SIMULATOR`
to its identifier and use a separate build directory:

```sh
xcodebuild build -project Examples/KeychainMigrationProbe/KeychainMigrationProbe.xcodeproj -scheme KeychainMigrationProbe -configuration Debug -destination "platform=iOS Simulator,id=$CLERK_PROBE_SIMULATOR" -derivedDataPath /tmp/clerk-keychain-probe-simulator DEVELOPMENT_TEAM="$CLERK_PROBE_TEAM"
xcrun simctl install "$CLERK_PROBE_SIMULATOR" /tmp/clerk-keychain-probe-simulator/Build/Products/Debug-iphonesimulator/KeychainMigrationProbe.app
xcrun simctl launch --console-pty "$CLERK_PROBE_SIMULATOR" com.clerk.nativecore.keychain-migration-probe
```

Debug builds use the active architecture, matching the local Swift package's
destination build. Without this setting the initial Simulator build also tried
to compile an x86_64 app against the arm64-only package module and failed to
resolve `ClerkKit`.

## Build evidence and limits

The physical iOS build and strict signature verification succeeded on September
10, 2026 with an existing profile that includes the paired iPhone. Its signed
entitlements contain the expected two distinct groups, and both Info.plist
group strings match them. The device was passcode locked during preparation. The later physical run
below now supplies runtime evidence for these isolated records.

Sandboxed certificate queries misleadingly returned no signing identities and
reported untrusted/invalid entitlements during inspection; verification outside
that restricted environment succeeded. Global manual profile settings also
conflicted with the automatically signed package resource bundle and the
Xcode-managed profile. The project now uses automatic signing. Custom report
keys are supplied through an explicit Info.plist because generated build-setting
keys alone did not appear in the built plist.

The September 10 Simulator run completed all 14 observations on iOS 26.5
(23F77), with reconstruction and durable-clear checks passing and fixture
cleanup completed before report creation. The
[saved report](../../Documentation/Migration/evidence/keychain-migration-probe-simulator.json)
contains synthetic markers only. The
[migration evidence](../../Documentation/Migration/legacy-metadata-access-groups.md)
explains the observed selection and its limits.

The expanded schema-version-2 run also completed all 24 observations, including
the 10 client-token cases. Its
[report](../../Documentation/Migration/evidence/keychain-migration-probe-client-simulator.json)
is retained alongside the initial metadata report. Both builds and strict
physical signature verification passed; the expanded diagnostic app is
installed on the paired iPhone. Its later physical run is recorded below.

After the metadata history correction, a third
[24-case Simulator report](../../Documentation/Migration/evidence/keychain-migration-probe-history-simulator.json)
records the new selection. Never-adopted metadata now uses the configured
group; adopted metadata preserves the previous omitted-group lookup. The two
earlier reports remain as before-fix evidence. Reconstruction, durable removal
and cleanup passed in the new run. Physical execution is recorded below.

## Physical run — September 10, 2026

At 09:14 ET the prepared diagnostic ran on the unlocked iPhone Air
(iPhone18,4), iOS 26.6.1 (23G83). The
[physical report](../../Documentation/Migration/evidence/keychain-migration-probe-history-physical.json)
has run identifier `2E7379F0-CA0F-473C-8A28-371F6E1FB9A0`. All 24
observations completed, reconstructed values matched imported values, durable
removal prevented reimport, and exact-service fixture cleanup succeeded before
the report was written. All imported-marker selections match the post-fix
Simulator report.

The default insertion used the declared private group. Omitted-group queries
returned both private and shared items for duplicate accounts. Never-adopted
metadata selected the configured shared group; adopted shared-only metadata
remained readable, and adopted duplicates selected the private marker in this
run. Client adoption markers without accepted local identity suppressed legacy
fallback, while accepted local credentials took precedence over shared records.
These are observed query results on this signed app/device, not a guarantee of
unspecified duplicate ordering.

This closes the pending physical source-selection probe for this configuration.
It does not prove real credential or biometric-key usability, actual platform
prompts, missing-entitlement combinations, or a signed-in old-major app upgrade.
