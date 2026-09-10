# User resource and service assertion audit

All 24 declarations in `Tests/Domains/User/UserTests.swift` and all 30 in `UserServiceTests.swift` were reviewed at baseline `02f98f89a19b6c079517c9aae07df7edd0e600e5`. Both files matched their recorded baseline SHA-256 before retirement. The inventory missed six resource and two service declarations involving availability annotations or multiline parameters; it now records all 54. Parameterized scenarios are not separate declarations.

The old resource tests assert arguments passed to a native mock service. The service tests inspect HTTP paths, methods and fields. The current owner is the actual TypeScript resource, invoked through the generated API. This audit retires these two files after the replacement checks below; it does not retire other authentication, platform, shared-session or upgrade tests.

## Shared defects reproduced

Clearing both first and last names left the old `User.fullName` on the existing resource. `User.fromJSON` now recomputes it for every response, including explicit null and empty names. Both cases are tested with a response that updates the existing object without replacing it through a client response, which would conceal the bug.

Deleting a profile image returned a deletion receipt without `name` or `public_url`. `Image.fromJSON` overwrote its nullable defaults with undefined, causing `invalid_projection:ImageResource.name` after successful deletion. It now retains canonical null defaults for absent fields. The [backend user handler](https://github.com/clerk/clerk_go/blob/33e0f8279c9b4e3d90d6e4788c67237bc6378a56/api/fapi/v1/users/service.go) delegates to [DeleteProfileImage](https://github.com/clerk/clerk_go/blob/33e0f8279c9b4e3d90d6e4788c67237bc6378a56/api/shared/users/service.go), which returns an image deletion receipt. The generated method returns a usable `ImageResource`, while the server's client update clears the user's image state. A complete image response also works; a rejected deletion preserves the old image. No native image mutation implementation or weakened projection type is added.

## Deliberate API and ownership changes

- Generated `User.update` and `updateMetadata` retain the canonical metadata behavior. Deprecated `update(unsafeMetadata:)` replaces the document: metadata-only calls first reload; profile-plus-metadata calls use the profile response as the fresh base. The computed merge patch removes missing keys with null, omits unchanged keys and treats a null base as empty. `updateMetadata` forwards an explicit deep-merge patch. HTTP carries one JSON-encoded `unsafe_metadata` form field. Native code does not calculate a second patch.
- Use `initialPage` and `pageSize` instead of offset. User invitation status is a single generated `OrganizationInvitationStatus`; the old array request is not supported as one call. An omitted filter replaces the old empty array. The common contract rejects an array before HTTP. Organization suggestions still support an array through the generated union (Swift `.case3`, Kotlin `Case3`); an empty array is omitted by the shared serializer.
- Effective PATCH/DELETE requests use POST plus `_method`. Boolean form values are `true`/`false`, replacing old `1`/`0` assertions. Collection paths may keep the canonical trailing slash, including `/me/backup_codes/`.
- External-account linking uses the configured native callback and completes provider authorization and client reconciliation before returning. The old per-call redirect override does not control the native browser callback. Additional scopes remain repeated fields. `oidcPrompt` is a space-separated string instead of an array of native prompt enums. Apple uses the host identity token when omitted, and preserves an explicitly supplied token without presenting identity again. Tokens are excluded from observed state.
- `createTotp`, `verifyTotp`, `disableTotp`, and `createBackupCodes` become `createTOTP`, `verifyTOTP`, `disableTOTP`, and `createBackupCode`. TOTP and backup-code objects are explicit value results. Enrollment secrets and recovery codes are not general observation state. TOTP removal returns a deletion value.
- `deleteProfileImage` becomes `setProfileImage` with an explicitly null file. Uploads use a typed file union containing bytes, filename and content type; string inputs remain another generated union case.
- `getSessions` returns generated `SessionWithActivities` resources. The old global `sessionsByUserId` cache is removed; the shared user resource owns its session list. A caller must not expect a removed native global cache to update.
- User deletion and leaving an organization apply the server's returned client. Successful user deletion tests supply cleared sessions and verify null user/session roots and stale old session handles. Rejections preserve roots. This does not claim that a receipt without a client independently clears all state; the old receipt-only service test asserted only the request, and the backend wraps deletion with its client response.

## Resource declarations

`U` is `packages/mobile-runtime/test/user-resources.test.mjs` (27 cases). `E` is `external-account.test.mjs`; `C` is `contact-resources.test.mjs`; `S` is `session-revocation.test.mjs`. These execute generated calls on the embedded TypeScript core with deterministic HTTP responses.

| Old declaration(s) | Replacement or explicit change |
| --- | --- |
| `reloadUsesUserServiceReload` | U metadata-only cases call `/me` and use the refreshed document, not stale local metadata. Private service dispatch is removed. |
| `updateUsesUserServiceUpdate` | U profile-plus-metadata checks John/Doe fields, effective PATCH, returned full name and retained resource identity. The two new clear-name cases cover the reproduced stale-field bug. |
| `updateMetadataUsesUserServiceUpdateMetadata` | U explicit deep-merge case checks one metadata request, JSON patch and resulting preserved/removed fields. |
| `updateWithIdenticalUnsafeMetadataReloadsAndDoesNotCallUpdateMetadata` | U identical case performs exactly one reload and no profile or metadata mutation. |
| `metadataOnlyDeprecatedUpdateUsesReloadedUnsafeMetadataForReplacementPatch` | U reloaded-current uses the fresh server document, removes server-only and nested obsolete keys with null, and omits unchanged nested keys. |
| `metadataOnlyDeprecatedUpdateTreatsReloadedNilUnsafeMetadataAsEmpty` | U reloaded-null sends the desired metadata as the replacement patch. |
| `profileAndDeprecatedMetadataUpdateTreatsProfileResponseNilUnsafeMetadataAsEmpty` | U profile-null uses the profile response with no extra reload, then sends the desired patch. |
| `createBackupCodesUsesUserServiceCreateBackupCodes` | U enrollment flow checks explicit returned codes and the updated user's backup-code flag; values are excluded from observation. |
| `createEmailAddressUsesUserServiceCreateEmailAddress`, `createPhoneNumberUsesUserServiceCreatePhoneNumber` | C checks supplied contact values, the returned generated resource and the updated user collection. See the [contact audit](contact-resource-test-audit.md). |
| `createExternalAccountUsesUserServiceCreateExternalAccount` | E create/reauthorize/recreate checks multiple scopes, prompt and full browser completion. Callback ownership and prompt input changes are explicit above. |
| `createExternalAccountTokenUsesUserServiceCreateExternalAccountToken` | E supplied Apple token case checks exact token, no identity/browser request, returned Apple account and canonical user reconciliation. |
| `createTotpUsesUserServiceCreateTotp`, `verifyTotpUsesUserServiceVerifyTotp`, `disableTotpUsesUserServiceDisableTotp` | U performs create, rejected verification, successful code verification, backup creation and disable; checks returned secret/URI/verified values, enrollment flags, exact paths and request code. |
| `getOrganizationInvitationsUsesUserServiceGetOrganizationInvitations` | U checks page 2 and a single pending filter; the old pending/accepted array is an explicitly removed input, with rejection before HTTP. |
| `getOrganizationMembershipsUsesUserServiceGetOrganizationMemberships` | U page 3 checks offset 20, limit 10, pagination marker and typed membership ID. |
| `leaveOrganizationUsesUserServiceLeaveOrganization` | U checks matching organization ID, deletion value, server-driven deselection and preserved selection on rejection. |
| `getOrganizationSuggestionsUsesUserServiceGetOrganizationSuggestions` | U checks page 2 with pending/accepted union-array values and empty-array omission, plus typed results. |
| `getSessionsUsesUserServiceGetSessions` | S calls the generated user entry point, reads activity fields from returned resources and revokes current/other sessions; removed private cache described above. |
| `updatePasswordUsesUserServiceUpdatePassword` | U checks supplied current/new passwords and the true sign-out flag, plus omitted-current/false behavior. |
| `setProfileImageUsesUserServiceSetProfileImage` | U checks exact binary bytes, filename, MIME type and returned image; string upload is separately checked. |
| `deleteProfileImageUsesUserServiceDeleteProfileImage` | U checks deletion receipt, complete image and rejection, effective DELETE and post-completion image fields. |
| `deleteUsesUserServiceDelete` | U checks user deletion path, applied cleared-client roots, stale session handle and rejection preservation. |

## Service declarations

U inspects exact resource paths, effective verbs, session query and form fields. These replace the old native service's request-handled flags rather than rebuilding that service.

| Old declaration(s) | Replacement or explicit change |
| --- | --- |
| `testReload`, `testUpdate` | U refreshed metadata and profile cases check GET/PATCH `/me`, names and same-resource state. |
| `updateWithUnsafeMetadataObjectUsesMetadataEndpoint` | U metadata-only replacement checks the reload followed by `/me/metadata` with exactly one JSON form field. |
| `updateMetadataUsesMetadataEndpoint` | U explicit patch checks direct metadata mutation and preserved unrelated nested fields in the returned response. |
| `updateWithProfileFieldsAndUnsafeMetadataSplitsRequestsAndPreservesReplacementSemantics` | U profile-current checks profile fields without metadata, then the exact null-delete/unchanged-key patch computed from the profile response, with no GET. |
| `testCreateBackupCodes` | U checks POST `/me/backup_codes/`, explicit returned codes and changed user flag. |
| `testCreateEmailAddress`, `testCreatePhoneNumber` | C checks POST contact collection fields and returned resources; canonical collection paths retain their trailing slash. |
| `testCreateExternalAccount`, `createExternalAccountWithExplicitRedirectUrl` | E checks configured native callback and provider completion. Per-call custom callback override is removed for native transport. |
| `createExternalAccountWithAdditionalScopes` | E checks repeated scope fields, preserving both values. |
| `createExternalAccountWithOIDCPromptArray`, `createExternalAccountWithOIDCMultiPromptArray`, `createExternalAccountWithScopesAndPrompts` | E checks the space-separated prompt together with repeated scopes and login hint. The native enum-array API is removed; absent prompt is checked by reauthorization. |
| `createExternalAccountToken` | E tests both host-generated and explicit supplied Apple tokens, exact form field and token exclusion from observed state. |
| `createTotp`, `verifyTotp`, `disableTotp` | U checks create, verification code and effective DELETE paths, returned values and changed enrollment state. |
| `testGetOrganizationInvitations`, `getOrganizationInvitationsWithStatuses` | U omitted and single pending status cases check page offsets and typed invitation IDs. Array input is explicitly rejected under the selected public TypeScript contract, even though the backend handler can accept multiple statuses. |
| `testGetOrganizationMemberships` | U checks GET, `paginated=true`, page size/offset and returned membership. |
| `leaveOrganization` | U checks effective DELETE `/me/organization_memberships/{id}`, receipt and applied client selection. |
| `testGetOrganizationSuggestions`, `getOrganizationSuggestionsWithStatuses` | U checks empty-array omission and repeated pending/accepted fields through the generated union, with equivalent pagination. |
| `testGetSessions` | S checks GET `/me/sessions/active`, the raw response array and generated activity records; the removed global cache assertion has no native replacement. |
| `testUpdatePassword`, `updatePasswordOmitsCurrentPasswordWhenNil` | U checks current/new passwords and `sign_out_of_other_sessions=true/false`; absent current password is omitted. |
| `testSetProfileImage` | U checks the multipart host payload byte-for-byte, filename/content type and returned image. Apple's HTTP capability suite separately verifies multipart encoding. These are not live upload claims. |
| `testDeleteProfileImage` | U checks effective DELETE and both supported response shapes. The old deletion-value API becomes `ImageResource` with null name/public URL for a receipt. |
| `testDelete` | U checks effective DELETE and successful/rejected outcomes. The old nil-client response did not assert state clearing; no new native sign-out policy is inferred from it. |

## Validation and remaining gates

The focused shared additions contain 27 user-resource cases and one supplied-token external-account case. All 428 embedded tests pass. Relevant source suites pass 33 tests. TypeScript compilation, generated-contract checks (342 types, 1,551 members, zero unsupported shapes) and bundle/Expo attached-transport reproducibility pass.

`NativeCoreContractTests/UserResourceTests.swift` and `NativeCoreTests/Android/UserResourceTest.kt` execute five generated scenarios against the packaged engine: clear names with null, clear names with empty strings, image deletion receipt, profile-plus-metadata replacement, and TOTP enrollment/verification/backup/removal. Before the shared fixes, the first three failed on both engines. All five now pass. Full suites pass 86 macOS tests in 14 suites, 83 iOS Simulator tests in 14 suites, and 89 Android instrumentation tests. Swift counts the parameterized declaration once. Android uses direct instrumentation, excluding only the separately opt-in live-startup and benchmark classes.

Both SDKs pin core `3e51e47681fb0f2b82657b18a203d29b1543d8dc`, contract `0f8387f260072ba6f894442b73d50afa6bda5f1205ed3c9209f5d6b1cfba16ce`, and bundle SHA-256 `bb5ea3e4535dbed5b5527c4876c422645bbca9af4bd0ff378d894c519345f5a5`. The final supplied-token test-only commit changes the source revision; packaged JavaScript bytes are identical to those used by the full native runs above.

Fixtures return explicit server documents; they do not duplicate metadata merging or native domain services. These checks do not establish live provider consent, OS credential presentation, physical-device performance, actual user deletion, or an old-major app upgrade. The retained legacy target still has other old-API compile gaps. Only the two audited user files are retired here.
