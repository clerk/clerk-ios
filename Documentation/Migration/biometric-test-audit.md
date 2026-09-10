# Biometric credential assertion audit

All assertion bodies in the five baseline files under `Tests/Domains/Auth/BiometricCredential` were reviewed at `02f98f89a19b6c079517c9aae07df7edd0e600e5`: `BiometricCredentialKeyManagerTests` (16 declarations), `BiometricCredentialLocalStoreTests` (21), `BiometricCredentialServiceTests` (5), `BiometricCredentialTests` (4), and `BiometricCredentialsTests` (50). All 96 names remain in `legacy-tests.json`; the original bytes matched its SHA-256 values before retirement. Helpers and parameter scenarios are not additional declarations.

The shared `NativeBiometricCredentials` implementation owns selection, enrollment, server reconciliation, metadata changes and cleanup. Apple retains Secure Enclave, Keychain, LocalAuthentication and encoding work. The generated `clerk.biometricCredentials` API and `signIn.biometricCredential` replace the old native service and authentication orchestration. This audit retires only these five files after the replacement checks below. Other Auth, shared-session and upgrade tests remain separate.

## Regressions reproduced and corrected

- Enrollment, revocation, user cleanup, server validation, authenticated availability and missing-key cleanup rewrote the storage list from only decodable records. This discarded unrelated malformed/older records, including another app's unknown fields. Mutation now preserves the raw list and removes only matching decoded identities. Decoding for selection is separate from persistence; old Android snake-case entries remain readable without rewriting unrelated entries.
- Corrupt JSON or a non-array document was treated as an empty list. Enrollment could overwrite it after creating a key and completing server work. It now reports `invalid_biometric_metadata` before key creation or a prompt. Structurally incomplete entries within a valid list remain preserved but cannot be selected.
- Reusing a server credential ID replaced its metadata without deleting its old private key. The prior decoded record is retained until the new metadata is saved, then its key is removed. A deletion failure preserves the committed new enrollment, matching the previous native policy.
- A cleanup read failure after saving enrollment escaped through the enrollment failure handler and deleted the new key. A read failure after server revocation also concealed the successful server result. These optional cleanup failures now preserve the successful result and usable committed enrollment.
- When the initiating session disappeared after server enrollment, local adoption was rejected without attempting server rollback. Rollback now covers that path and a selection change during metadata persistence. It removes newly persisted metadata and keys where cleanup succeeds. Requests retain the initiating session ID: `FapiClient.request` previously overwrote that explicitly supplied value with the current selection; it now honors the request value and falls back to the selected session when omitted.

Rollback and cleanup remain best-effort after remote effects. The deterministic tests accept rollback requests and verify their session/path; they do not promise rollback succeeds after a real server has revoked the session or a device has become inaccessible. User cleanup retains its pending journal on failure for later retry. These are shared TypeScript fixes, with no second Swift/Kotlin selection or rollback implementation.

## API and platform differences

`signIn.biometricCredential` operates on the canonical future sign-in, lowers its error envelope and leaves finalization explicit. It does not return the old native `SignIn` value or activate its created session implicitly. Challenge data, signatures and local key IDs are not general observation state. `validateLocalCredentialIfPossible` becomes `validateLocalCredential`; current-user selection uses `currentUser: true` in the generated parameter object. Local availability is asynchronous because it crosses the capability boundary.

An enrollment whose initiating session changes is rejected as stale. This intentionally replaces the old behavior that continued enrollment against the previous session after a different session became selected. Cleanup still uses the initiating session, rather than accidentally addressing the newly selected user. Unknown platform/algorithm/status output values remain readable through the generated open unions; input policy values remain the three supported policies.

The old standalone Codable models and public/private local-store constructors are removed. `BiometricCredential` is a generated value with dates and typed union fields. Clerk request construction uses POST with `_method=DELETE` for effective deletion. Storage and key errors cross the structured native error boundary rather than retaining the old native error enum/message constructors.

The old all-app `deleteAllLocalCredentials` and global Keychain-clear API are unavailable. `forgetLocalCredentials(userId:)` affects that user in the current app and records pending cleanup. Installation reconciliation handles recoverable malformed current-app entries before marking an Apple installation current. It preserves other apps' raw entries and leaves the marker unset after failure. This is an explicitly different scope and persistence sequence; it is not a replacement global-clear API. See [installation continuity](biometric-installation.md) and the [Clerk storage audit](clerk-storage-test-audit.md).

## Key-manager declarations

`K` is `NativeCoreContractTests/AppleBiometricKeyTests.swift`. Its fourteen retained platform/encoding declarations call the actual current Apple key manager. The two old tests of a mock implementation are replaced by source/bridge behavior below rather than by a new mock protocol.

| Old declaration(s) | Current evidence or explicit change |
| --- | --- |
| `localKeyDefaultsToBiometryCurrentSetPolicy` | K checks the default local-key policy. Shared enrollment cases verify Apple default current-set, Android default device-passcode and explicit policies. |
| `privateKeyAttributesUseSecureEnclaveAccessControl` | K checks EC P-256, Secure Enclave, permanent private key, access control, stable UTF-8 application tag and macOS Data Protection flag. |
| `accessControlFlagsMatchBiometricCredentialPolicies` | K retains private-key usage plus current-set, any-biometry or user-presence flags for all three policies. |
| `localAuthenticationPoliciesMatchBiometricCredentialPolicies`, `localAuthenticationPoliciesForKeyCreationRequireBiometrics` | K preserves use-policy mapping and the stronger biometrics-required key-creation check. It does not claim an actual device prompt succeeded. |
| `privateKeyQueryUsesStableApplicationTag` | K checks private EC key class, exact `dev.clerk.trusted_device.tdlk_123` bytes and macOS backend selection. |
| `publicKeyJWKEncodesP256X963Representation`, `publicKeyJWKRejectsInvalidRepresentation` | K checks exact P-256 X/Y bytes, URL-safe base64, algorithm and rejection of invalid X9.63 data. |
| `failedPublicKeyExportDeletesCreatedKeyAndPreservesExportError` | K checks attempted deletion and preservation of the original export failure. |
| `base64URLEncodingOmitsPadding` | K preserves the explicit `-__v` vector and omitted padding. |
| `rawES256SignatureConvertsDEREncodedSignature`, `rawES256SignaturePadsShortDERIntegers`, `rawES256SignatureRejectsMalformedDER` | K checks high-bit integer padding, short integer left-padding, exact 64-byte output and malformed DER rejection. |
| `privateKeyLookupStatusMapsBiometricErrors` | K preserves cancellation/authentication/unavailable mapping; other OSStatus values now appear in `CoreError.code` as `secure_storage_error_<status>`. |
| `mockKeyManagerSignsClientData`, `mockKeyManagerSurfacesMissingKey` | Removed mock-only APIs. Shared generated sign-in checks the exact client data, signature and algorithm request; missing-key availability removes the unusable metadata and does not sign. Packaged generated enrollment/sign-in and metadata tests exercise the actual bridge. |

## Local-store declarations

`B` is `packages/mobile-runtime/test/biometrics.test.mjs`, now 80 cases. It runs generated calls through the embedded core, with explicit host storage and key responses. It does not replicate selection or cleanup algorithms in the host.

| Old declaration(s) | Current evidence or explicit change |
| --- | --- |
| `saveAndLoadCredentialMetadata` | B enrollment persists a record that generated local availability subsequently reads. Direct store construction is removed. |
| `saveReplacesExistingCredentialMetadata`, `saveDeletesReplacedLocalKeyAfterOverwritingMetadata` | B same-ID enrollment checks the new key reference, a single replacement record and removal of the old key after persistence. |
| `saveKeepsUpdatedMetadataWhenReplacedKeyDeletionFails` | B failed old-key deletion preserves the new record and successful local availability. |
| `saveKeepsExistingMetadataAndKeyWhenReplacementPersistenceFails` | B storage failure rejects enrollment, rolls back the new server credential and removes only the new key. Existing metadata is retained. |
| `deleteCredentialMetadata` | B generated revoke and user cleanup remove the matching metadata after key deletion, preserving unrelated entries. |
| `localCredentialCanBeBuiltFromServerCredentialAndLocalKey` | B enrollment checks user ID, app ID, local key, explicit policy and normalized hint derived from server/client/host inputs. |
| `emptyIdentifierHintIsNotPersisted` | B independently tests blank and omitted hints becoming null, unfiltered local selection and rejection of a nonmatching hint. Direct `matches` and Codable omission semantics are removed, rather than promised as a public store API. |
| `credentialMetadataRequiresPolicy`, `credentialMetadataRequiresUserID` | B independently omits each field and checks unavailable selection with no signature while preserving the raw entry. Apple's missing policy is not defaulted; the separately tested old Android omitted policy has its documented device-passcode default. |
| `deleteAllLocalCredentialsDeletesKeysAndMetadata` | Global all-app deletion is removed. B scoped user cleanup deletes both matching records; installation checks cover current-app reinstall cleanup. |
| `deleteAllLocalCredentialsPreservesMetadataForFailedKeyDeletions`, `deleteAllLocalCredentialsStopsAfterMetadataPersistenceFails` | B scoped cleanup checks key/write failure, retained metadata and journal, untouched later keys and successful retry. It does not claim the old global loop's partial-progress ordering. |
| `deleteLocalCredentialsDeletesOnlyMatchingAppIdentifier` | B user cleanup and enrollment preserve other-app records and keys. |
| `appScopedReadsAndSavesIgnoreMalformedCredentialsForOtherApps` | B's six mutation-path regressions preserve the other app's incomplete record and nested unknown fields. |
| `appScopedReadsSkipMalformedCredentialsForCurrentApp` | B skips incomplete current-app entries for selection and retains them during ordinary mutations. Installation reconciliation separately handles recoverable keys from those entries. |
| `deleteAllLocalCredentialsDeletesMalformedMetadataAfterDeletingKeys`, `deleteAllLocalCredentialsDeletesRecoverableKeysFromPartiallyMalformedMetadata` | Removed global-clear API. Existing installation tests delete recoverable current-app keys from incomplete records, drop only that app's entries and preserve other apps before marking completion. |
| `deleteAllLocalCredentialsPreservesMalformedMetadataForFailedKeyDeletions`, `deleteLocalCredentialsDeletesOnlyMatchingAppIdentifierFromMalformedMetadata` | Installation failure leaves the marker unset and metadata retryable; other-app records remain. Ordinary generated mutations also preserve unrelated malformed records. The old all-app deletion contract is explicitly absent. |
| `corruptCredentialMetadataThrows` | B tests corrupt JSON and a non-array document; enrollment fails before key creation, HTTP enrollment and writes. Validation converts storage uncertainty to inconclusive rather than deleting credentials. The exception is a structured shared error, not Swift `DecodingError`. |

## Service and value declarations

| File / old declaration(s) | Current evidence or explicit change |
| --- | --- |
| Service `list` | B checks GET, initiating session query and the complete returned value, including dates and nullable revocation time. Both packaged engines check the generated list result. |
| Service `prepareEnrollment`, `attemptEnrollment` | B checks platform, app identifier, name, ES256, exact JWK, client data, signature, POST and initiating session on both endpoints. Explicit policies and prompt reason/subtitle reach the host. |
| Service `validateSignInCredential` | B checks POST `/client/biometric_credentials/validate` and exact `trusted_device_id`, with valid, missing, disabled and inconclusive outcomes. |
| Service `revoke` | B checks effective DELETE and returned revoked value, including local read/write/key failures. Both packaged engines prove the read-failure result. |
| Value `biometricCredentialDecodesBackendShape` | B known/future list cases and native list checks preserve ID, object, platform, app, name, algorithm/status, millisecond dates and null revocation time. Old Codable constructors are removed. |
| Value `biometricCredentialChallengeDecodesBackendShape`, `verificationDecodesBackendBiometricCredentialChallenge` | B creates a real future sign-in, validates challenge identity/algorithm/expiry and signs exact client data. Missing, mismatched and expired challenges fail before a prompt. Challenge material remains private instead of becoming general observed state. |
| Value `prepareEnrollmentParamsEncodeBackendKeys` | B's exact prepare/attempt body checks replace the old native encoder test. TypeScript constructs these fields. |

## BiometricCredentials declarations

| Old declaration(s) | Current evidence or explicit change |
| --- | --- |
| `listUsesBiometricCredentialService`, `revokeUsesBiometricCredentialService` | B invokes generated list/revoke, checks source HTTP and typed returned values. The old service-dispatch flags are removed. |
| `availabilityReturnsAvailableLocalCredentialWithoutActiveSession`, `availabilityReturnsAvailableWithMultipleLocalCredentials` | B signed-out availability and newest-record sign-in select usable local records without an authenticated list request. |
| `availabilityReconcilesServerCredentialWhenSessionIsActive`, `availabilitySkipsStaleNewerCredentialWhenSignedIn` | B authenticated selection retains the older valid credential after deleting a newer missing credential. |
| `localAvailabilityDoesNotReconcileServerCredentialWhenSessionIsActive` | B explicitly checks no biometric HTTP while local availability is available for a signed-in owner. |
| `validateLocalCredentialIfPossibleReturnsValidForServerCredential` | B validation keeps the valid local record and returns the generated valid result. |
| `validateLocalCredentialIfPossibleDeletesMissingServerCredential`, `validateLocalCredentialIfPossibleSkipsMissingNewestCredential` | B checks both false validation and a matching missing-resource error, plus newest-to-oldest retry after removing only the missing entry. |
| `validateLocalCredentialIfPossibleKeepsCredentialForTransientError` | B returns inconclusive on service failure and preserves local metadata. Unrelated missing-resource parameters do not authorize deletion. |
| `validateLocalCredentialIfPossibleIsInconclusiveWithoutCachedClient` | The old mutable cached-client bootstrap state is unavailable on the connected generated facade. Shared validation explicitly returns inconclusive without a client; this old private-state construction is not claimed as a packaged native scenario. |
| `availabilityDoesNotReconcileServerCredentialWhenSessionIsExpired` | B supplies an expired session and checks usable local availability with no authenticated list. |
| `availabilityReturnsFeatureDisabledWhenNativeSettingIsOff` | B separately checks native API disabled and biometric feature disabled reasons without signing. |
| `availabilityDeletesMetadataWhenLocalKeyIsMissing` | B missing-key availability removes only the selected metadata and preserves unrelated raw entries. |
| `availabilityDeletesMetadataWhenServerCredentialIsMissing` | B authenticated empty-list reconciliation deletes the missing local key and metadata. |
| `availabilityIgnoresCredentialFromDifferentAppIdentifierBeforeCheckingKeys`, `signInUsesCurrentAppCredentialWhenSharedKeychainContainsNewerCredential` | B selection includes a newer other-app record; source sign-in uses the current app and preserves the other key/record. |
| `availabilityIgnoresCredentialOwnedByDifferentUserWhenSignedIn` | B other-user-only availability returns no local credential and issues no authenticated list or deletion. |
| `availabilitySkipsNewestCredentialOwnedByDifferentUserWhenIdentifierHintIsNil`, `signInSkipsCredentialOwnedByDifferentUserWhenSessionIsActive` | B authenticated selection chooses the current user's older record, preserves the other user and sends the matching ID. |
| `availabilityUsesUserIDWhenIdentifierHintChanged`, `localAvailabilityUsesUserIDWhenIdentifierHintChanged` | B `currentUser: true` bypasses an obsolete hint for both local and reconciled availability. |
| `enrollCreatesKeyPreparesChallengeAttemptsAndPersistsMetadata` | B complete enrollment checks HTTP fields, supplied prompt, normalized hint, user ID, policy and saved key; native packaged enrollment checks use the same TypeScript owner. |
| `enrollPinsInitiatingSessionAcrossCurrentSessionChange` | New stale-operation policy rejects losing the initiating session. B checks no signature after loss during prepare, and rollback after loss during attempt. The initiating session remains pinned on requests. The old continue-after-selection-change behavior is not preserved. |
| `enrollUsesInitiatingSessionForRollbackAfterLocalSaveFailure` | B failed-save rollback and loss-during-save checks preserve the initiating session query; source FAPI tests independently verify explicit-session precedence and default fallback. |
| `enrollReplacesOtherCurrentAppCredentialsAcrossUsersAfterSuccessfulEnrollment`, `enrollDoesNotCallBackendRevokeForReplacedLocalCredentials` | B successful enrollment removes old current-app keys and metadata without revoking those replaced server IDs; other apps remain. Server rollback is reserved for a newly created enrollment that cannot be adopted. |
| `enrollKeepsExistingCredentialsWhenEnrollmentFails`, `enrollDeletesGeneratedKeyWhenAttemptFails` | B rejected/failed enrollment and storage failure remove the newly created key while preserving existing records. Lost-session rollback also retains the prior record when its ID differs. |
| `enrollAllowsPendingSession`, `enrollRequiresActiveOrPendingSession` | B active/pending/signed-out cases exercise the generated methods; signed-out enrollment fails before a prompt. |
| `enrollDefaultsToBiometryCurrentSetPolicy` | B Apple default and explicit policy cases check host creation and persisted policy. Android's default is separately checked. |
| `revokeDeletesLocalCredentialAfterServerRevoke`, `revokeReturnsServerCredentialWhenLocalCleanupFails` | B checks successful removal and all three local cleanup failure stages while returning the revoked server value. |
| `revokeCurrentDeviceCredentialUsesUserIDWhenIdentifierHintChanged` | B current-device revocation chooses the current user and preserves another user's record. Selection's current-user cases separately prove changed-hint handling. |
| `revokeCurrentDeviceCredentialReturnsNilWhenNoLocalCredentialIsAvailable` | B the second current-device revoke returns null when only another user's record remains. |
| `revokeCurrentDeviceCredentialAllowsPendingSession`, `revokeCurrentDeviceCredentialRequiresActiveOrPendingSession` | B pending enrollment/revoke and signed-out failure cases preserve the eligibility rule. |
| `forgetLocalCredentialsDeletesDeletedUserIDAfterCurrentUserIsCleared` | B account-scoped cleanup starts signed out, accepts the explicit user ID, preserves other users/apps and retains a failed cleanup journal for retry. |
| `availabilityUsesStoredCredentialPolicy` | Existing B legacy Android policy checks and explicit enrollment policies verify the actual policy sent to the host; no second native selection rule is introduced. |
| `availabilityReturnsNoLocalCredentialWhenIdentifierHintDoesNotMatch` | B hint mismatch returns unavailable without biometric HTTP or local deletion. |
| `signInUsesCreateChallengeAndAttemptsFirstFactor` | B generated future sign-in checks trusted-device ID, strategy, exact client data/signature/algorithm and complete state without implicit session adoption. |
| `signInUsesNewestLocalCredentialWhenNoIdIsProvided`, `signInUsesIdentifierHintToSelectMatchingLocalCredential` | B explicit ID, newest record and trimmed/case-normalized hint select the matching key and sign-in request. |
| `signInDeletesLocalCredentialWhenCreateReportsBiometricCredentialMissing`, `signInDeletesLocalCredentialWhenAttemptReportsBiometricCredentialMissing` | B matching missing-resource errors remove the key and metadata at either stage; core error codes/metadata replace the old synthesized native message. |
| `signInKeepsLocalCredentialWhenCreateFailsForUnrelatedAPIError` | B missing-resource error on `identifier` retains the credential and reports the source error. |
| `signInSkipsStaleNewerCredentialWhenSignedIn` | B authenticated stale-newest case reconciles first, deletes only the missing record and signs with the older valid ID. |
| `signInRequiresCreateToReturnBiometricCredentialChallenge` | B absent-challenge response fails with no signature and no separate prepare-first-factor request. |

## Validation and limits

All 483 embedded tests pass, including the 80-case biometric suite. Runtime TypeScript compilation, generation (342 types, 1,551 members, zero unsupported shapes) and bundle/Expo attached-transport reproducibility pass. The FAPI source suite passes 48 tests, with one pre-existing skip and four TODOs. The complete native suites pass 101 macOS tests in 15 suites, 98 iOS Simulator tests in 15 suites and 97 Android instrumentation tests. Swift counts the parameterized metadata declaration once. Android invokes the runner directly, excluding only the separately opt-in live-startup and benchmark classes.

The new native metadata suite runs eight scenarios: enrollment/raw preservation, scoped cleanup, corrupt storage, same-ID replacement, revoke-read failure, saved-enrollment cleanup-read failure, returned list fields and loss of the initiating session. Before repackaging, seven failed on both JavaScriptCore and QuickJS; list projection already passed. The fourteen Apple key-manager tests passed on the preceding bundle as well. These tests use actual generated APIs and packaged engines; HTTP, secure-key effects and metadata storage are deterministic fixtures.

Both SDKs pin core `a84ea393f45d7936fd2cc07ea089b9ced835ebeb`, contract `0f8387f260072ba6f894442b73d50afa6bda5f1205ed3c9209f5d6b1cfba16ce`, and bundle SHA-256 `37f500945eaff6c0be7787f9dd3c75163ed8b604d4e466ff5a1d7a2f8409c237`. The manifests and bundle bytes match across the two native packages.

The existing credential-storage and installation-marker suites remain. Their synthetic storage/import checks do not establish a released signed-in app upgrade, a real uninstall/restore, physical biometric enrollment or prompt, shared-owner convergence, or live server cleanup after revocation. Those release gates remain open. This audit does not remove the separate Auth or shared-session suites or turn their remaining compile gaps into passing tests.
