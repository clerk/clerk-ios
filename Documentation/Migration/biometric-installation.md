# Biometric installation continuity

The core at pin `617418e19c` reconciles local biometric metadata before use when
the host advertises `biometrics.installation`. Apple capabilities provide this
optional capability through app-container `UserDefaults`; Android hosts do not
advertise it. The Apple core privacy manifest now declares its UserDefaults use
with reason `CA92.1`, alongside the UI target's existing declaration.

## Upgrade and new-install behavior

A new marker is scoped to the app identifier and publishable key. Before one
exists, the adapter recognizes the previous major's marker only when
`LegacyKeychainConfiguration.publishableKey` explicitly matches this instance.
It reproduces the original service/access-group/app UTF-8 length encoding,
including the originally supplied access-group spelling. Credential reads still
use the normalized Keychain access group. Missing and literal access groups do
not collide, and a marker for another application or instance is not adopted.

A recognized marker preserves enrollment and establishes the new marker. When
neither marker exists, TypeScript deletes the current app's surviving local
biometric keys and removes its metadata. Other applications' records, including
unknown fields, remain intact. The host only reads/writes the marker and performs
key/storage operations; Swift does not select credentials or own a second
biometric authentication flow. Existing client credentials and sessions are not
cleared by this operation.

The marker is written only after key deletion and metadata persistence succeed.
A failure leaves reconciliation pending. Later biometric selection, enrollment
or cleanup retries it; concurrent calls share the same reconciliation. Failed
reconciliation cannot proceed to a biometric signature. An unreadable or
malformed metadata list also leaves the marker unset instead of claiming that
unknown keys were removed. Successful deletion followed by a failed write can
retry the same key: the Apple deletion adapter accepts an already-missing key.

The previous global all-Keychain-items clear API is still absent. This restores
the installation-specific biometric behavior, not that separate API.

## Evidence and limits

`AppleBiometricInstallationTests` checks literal previous-major marker keys,
UTF-8 and dotted configuration boundaries, the original access-group spelling,
explicit instance authorization, current marker reconstruction, app/key
isolation, marker disappearance, and rejected cross-instance capability calls.
Its packaged-core test uses the real Apple capability advertisement and marker
routing with an isolated UserDefaults suite. The previous bundle failed to
remove the old key or establish the new marker. The updated bundle preserves an
existing installation and reconciles a missing marker through TypeScript.

Embedded tests cover other-app preservation, malformed current-app records,
key deletion failure, read/write/marker failures and coalesced retries. An
attached-core test performs reconciliation on the existing JavaScript owner
without changing its client credential or issuing initialization HTTP again.

Key deletion and HTTP in these packaged tests are fixtures. Removing an isolated
UserDefaults suite simulates marker loss; it is not proof of actual uninstall,
backup restore, a physical biometric prompt, or a signed-in released-app upgrade.
Those platform journeys remain release gates. These tests also do not establish
live operation by multiple SDK owners against the same storage.

Validation for this change: source type checking passes, the embedded suite
passes 220 tests, Apple passes 63 iOS Simulator and 66 macOS contract tests,
and Android's separate packaged suite passes 11 tests with the optional
installation capability absent. These counts describe the executed suites;
they are not a complete native migration coverage figure.
