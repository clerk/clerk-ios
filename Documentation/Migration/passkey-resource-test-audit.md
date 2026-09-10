# Passkey resource and service assertion audit

All four declarations in `Tests/Domains/Auth/Passkey/PasskeyServiceTests.swift` and all four in `PasskeyTests.swift` were reviewed at baseline `02f98f89a19b6c079517c9aae07df7edd0e600e5`. Their assertions cover request construction, mock service dispatch, and a relying-party getter. They do not exercise a system prompt or live credential enrollment.

The replacement path is generated `User.createPasskey`, followed by generated `Passkey.update` and `Passkey.delete`. Registration runs the existing TypeScript `Passkey.registerPasskey`: create a challenge, invoke the native credential capability, and submit the returned credential. It does not expose the old instance `attemptVerification` API for arbitrary credential strings.

## Generator regression

A Kotlin consumer of `Passkey.update` exposed its incorrectly generated `Partialtype` parameter. The TypeScript declaration exports `UpdatePasskeyParams`, but the compiler counted the same symbol once per barrel re-export. It therefore treated a unique exported alias as ambiguous and fell back to the utility type name. A compiler fixture with two re-exporting barrels reproduces the error. Deduplicating symbol identities preserves the real alias in both languages. The API diff changes only `Partialtype` to `UpdatePasskeyParams`; field semantics remain `Field<String>` with omitted/null/value support. Expo's attached contract and both bundled contracts are regenerated together. The Compose rename caller uses the corrected generated type.

## Assertion map

| Old declaration | Replacement evidence or explicit change |
| --- | --- |
| `PasskeyServiceTests.testCreate` | Generated registration checks POST `/v1/me/passkeys`, followed by one native creation request. |
| `PasskeyServiceTests.testUpdate` | Generated rename checks the exact passkey path and name. The shared transport uses POST with `_method=PATCH`, replacing the old physical PATCH assertion. |
| `PasskeyServiceTests.testAttemptVerification` | Registration checks POST to the same passkey's `attempt_verification`, passkey strategy and credential JSON containing the host's attestation. The old arbitrary string input is removed. |
| `PasskeyServiceTests.testDelete` | Generated delete checks the same passkey path and the shared transport's POST with `_method=DELETE`, then returns its declared deletion receipt. |
| `PasskeyTests.updateUsesPasskeyServiceUpdate` | Rename returns the same generated resource handle with the new name published before completion. |
| `PasskeyTests.attemptVerificationUsesPasskeyServiceAttemptVerification` | Replaced by the complete shared registration path; no second native registration orchestration or manual credential-submission helper survives. |
| `PasskeyTests.deleteUsesPasskeyServiceDelete` | Delete returns the passkey ID and `deleted: true`; the previously returned resource remains readable. The embedded test also checks the user passkey collection from the returned client. |
| `PasskeyTests.relyingPartyIdentifierReadsRegistrationNonce` | The old convenience getter is removed. Registration checks `example.com` in the actual host request, alongside binary challenge/user IDs. The separate platform capability tests inspect AuthenticationServices and Credential Manager requests. |

The embedded registration suite has a successful create/rename/delete case and a native-cancellation case. Both packaged native engines run the same public operations. Cancellation must preserve its error code and prevent verification submission. Swift fixture issues (a null request body and form-encoded `+` spaces) were corrected before accepting its results; they were not runtime defects.

Validation includes all 15 compiler tests and 353 embedded tests after the adjacent organization-defaults fix. Native validation is recorded in [organization defaults](organization-defaults-test-audit.md), which pins the same release bundle. These two legacy passkey files are retired after that validation. Live OS enrollment, sign-in with an enrolled passkey, and upgrade continuity remain independent release gates.
