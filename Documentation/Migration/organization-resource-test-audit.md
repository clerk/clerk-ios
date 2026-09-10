# Organization resource and service assertion audit

All 39 declarations in `Tests/Domains/Organization/OrganizationTests.swift` and all 38 in `OrganizationServiceTests.swift` were reviewed at baseline `02f98f89a19b6c079517c9aae07df7edd0e600e5`. Their bytes still matched the recorded baseline hashes before retirement. The earlier inventory missed four multiline parameterized declarations in `OrganizationTests`; `legacy-tests.json` now includes them. Parameter cases are not counted as separate declarations.

The old resource tests mainly capture arguments sent to a native mock service. The service tests construct HTTP responses and inspect requests. Their replacements call generated resources backed by the existing TypeScript implementation. The two old files are retired after the checks below; unresolved hosted authentication, platform operations, and app-upgrade gates are not retired by this audit.

## Reproduced defects

- `Organization.setLogo({ file: null })` previously tried to construct an organization from an image deletion receipt. The backend returns that receipt in [DeleteLogo](https://github.com/clerk/clerk_go/blob/33e0f8279c9b4e3d90d6e4788c67237bc6378a56/api/fapi/v1/organizations/service.go). The shared resource now reloads the organization after a successful image receipt. Complete organization responses remain accepted. If deletion or refresh fails, the error propagates and the held resource remains readable; a failed refresh does not mean the deletion was rolled back.
- `getInvitations({ status: [] })` serialized a blank status. The server reads and validates each status in [the invitation handler](https://github.com/clerk/clerk_go/blob/33e0f8279c9b4e3d90d6e4788c67237bc6378a56/api/fapi/v1/organization_invitations/http.go) and its service. The shared pagination utility now omits empty arrays. Nonempty role/status arrays still reach HTTP as repeated fields through the existing FAPI serializer.
- A separately returned organization with the active root's server ID reused that root's handle. Subsequent root reconciliation overwrote the returned fields with the older root. The generic runtime now preserves a separate handle for a distinct returned instance instead of rebinding a live root by server ID. Returning the exact root instance still preserves its handle; the existing collection identity policy remains in effect. Both `getOrganization` and a complete organization logo response reproduce this problem.

These are shared resource/runtime fixes. No ordinary organization endpoint or mutation is reimplemented in Swift or Kotlin. The pinned backend source supports the response/filter contracts; these tests use deterministic host responses, not live HTTP.

## New-major API changes

- Use generated `initialPage` and `pageSize`. Old explicit offset examples map to equivalent whole pages (offset 20/size 10 is page 3; offset 30 is page 4). Arbitrary offset is no longer an organization-resource option.
- The shared transport uses POST with `_method=PATCH`, `_method=DELETE`, or `_method=PUT` where appropriate. The old physical-verb assertions are replaced by checks of the effective method, exact path, body and session query.
- `setLogo` takes a typed upload union or an explicitly null file and returns an organization. Deletion no longer exposes an image receipt to the application. Binary uploads preserve filename, MIME type and byte content across the host request; native HTTP owns multipart encoding.
- `OrganizationDomain.enrollmentMode` is the generated typed property, including unknown output values. The old `enrollmentModeType` wrapper is removed. An unknown enrollment query input now fails before HTTP under the common closed-input enum policy; preserving an unknown read value does not authorize writing it.
- `sendEmailCode` and `verifyCode` aliases become `prepareAffiliationVerification` and `attemptAffiliationVerification`. `isVerified` is replaced by reading the reported verification status; null remains null. The generated methods do not infer success from completion alone.
- `OrganizationMembership` permission convenience methods are removed. Read its generated permission list for a membership, or use the generated session authorization API for the active session. The old mutable optional permission list is now a readonly list normalized by TypeScript. No native permission state machine is retained.
- Keep returned resources where the TypeScript method returns a distinct instance. Swift profile uploads already use the returned organization; its deletion path refetches. Compose profile saving explicitly reloads the held organization. These callers remain compatible with the corrected resource identity behavior.

## Resource declarations

Each row names the old declaration or explicitly groups equivalent service-dispatch assertions. `R` means `packages/mobile-runtime/test/organization-resources.test.mjs`; `M` means the existing `organization.test.mjs` membership-deletion scenarios; `L` means the [organization account-list audit](organization-list-test-audit.md) and its packaged native UI tests.

| Old declaration(s) | Replacement or explicit change |
| --- | --- |
| `decodesOrganizationWithoutImageUrl` | R returns organizations with no image URL and checks canonical empty string/false after logo removal. |
| `updateOrganizationUsesOrganizationServiceUpdateOrganization` | R update checks name, optional slug, effective PATCH, returned name/slug. |
| `destroyOrganizationUsesOrganizationServiceDestroyOrganization` | R destroy checks organization path, deletion receipt handling, readable held ID. The generated result is void. |
| `setOrganizationLogoUsesOrganizationServiceSetOrganizationLogo` | R binary/string uploads check bytes, filename/content type, effective PUT, and returned image state. |
| `deleteOrganizationLogoUsesOrganizationServiceDeleteOrganizationLogo` | R receipt/full-resource/error outcomes plus native six-scenario suite below. |
| `getOrganizationRolesUsesOrganizationServiceGetOrganizationRoles` | R page 2 checks limit/offset, role ID, total count and `has_role_set_migration`. |
| `getOrganizationMembershipsUsesOrganizationServiceGetOrganizationMemberships`, `getOrganizationMembershipsWithOffsetUsesOrganizationServiceGetOrganizationMemberships` | R membership pages check query omission/value, role filters, `paginated=true`, and equivalent page 3/page 4 offsets. |
| `addOrganizationMemberUsesOrganizationServiceAddOrganizationMember` | R add checks user ID and member role on the collection path. |
| `updateOrganizationMemberUsesOrganizationServiceUpdateOrganizationMember` | R update checks supplied user ID, admin role and returned role. |
| `removeOrganizationMemberUsesOrganizationServiceRemoveOrganizationMember` | R remove checks supplied user ID and returned membership. The backend membership-delete response is a membership, not the image deletion receipt. |
| `updateOrganizationMembershipUsesOrganizationServiceUpdateOrganizationMember` | R membership update uses the resource's organization and public user ID and checks returned role. |
| `destroyOrganizationMembershipUsesOrganizationServiceDestroyOrganizationMembership` | M and the packaged Swift/Kotlin membership-deletion suites check client deselection and readable return values. |
| `organizationMembershipPermissionHelpers` | Removed convenience APIs as described above. R returns generated memberships; the existing session authorization suite covers generated role/permission decisions. It does not claim to retain the old mutable helper API. |
| `getOrganizationInvitationsUsesOrganizationServiceGetOrganizationInvitations`, `getOrganizationInvitationsWithOffsetUsesOrganizationServiceGetOrganizationInvitations` | R checks empty, pending and pending/accepted filters with equivalent page offsets. |
| `inviteOrganizationMemberUsesOrganizationServiceInviteOrganizationMember` | R checks one email and role, returned invitation ID/status. |
| `inviteOrganizationMembersUsesOrganizationServiceInviteOrganizationMembers` | R checks repeated email fields, role, and both returned invitations. |
| `createOrganizationDomainUsesOrganizationServiceCreateOrganizationDomain` | R create checks domain name, organization path and returned domain. |
| `getOrganizationDomainsUsesOrganizationServiceGetOrganizationDomains`, `getOrganizationDomainsWithOffsetUsesOrganizationServiceGetOrganizationDomains` | R checks unfiltered domain pages and equivalent offset/size, returned null verification. |
| `getOrganizationDomainsWithEnrollmentModeUsesRawEnrollmentMode` | R checks both known automatic enrollment filters. Unknown input now fails before HTTP; unknown output remains readable. |
| `getOrganizationDomainUsesOrganizationServiceGetOrganizationDomain` | R lookup checks the exact organization/domain path and returned ID. |
| `getOrganizationMembershipRequestsUsesOrganizationServiceGetOrganizationMembershipRequests`, `getOrganizationMembershipRequestsWithOffsetUsesOrganizationServiceGetOrganizationMembershipRequests` | R checks omitted/pending status and equivalent page offsets. |
| `deleteOrganizationDomainUsesOrganizationServiceDeleteOrganizationDomain` | R delete checks exact path/effective DELETE and readable held ID after the receipt. |
| `prepareAffiliationVerificationUsesOrganizationServicePrepareOrganizationDomainAffiliationVerification`, `sendEmailCodeUsesOrganizationServicePrepareOrganizationDomainAffiliationVerification` | R prepare checks affiliation email and unverified returned state; convenience alias removed. |
| `attemptAffiliationVerificationUsesOrganizationServiceAttemptOrganizationDomainAffiliationVerification`, `verifyCodeUsesOrganizationServiceAttemptOrganizationDomainAffiliationVerification` | R attempt checks code and verified returned state; convenience alias removed. |
| `organizationDomainEnrollmentModeTypeUsesTypedMode` | R reads known and future modes through the generated typed property; old secondary getter removed. |
| `organizationDomainIsVerifiedUsesVerificationStatus` | R projects verified, unverified and null states. Read the generated status instead of the removed Boolean helper. |
| `organizationDomainDecodesNullVerification` | R domain lookup/list preserves null verification and affiliation email. |
| `updateOrganizationDomainEnrollmentModeUsesOrganizationServiceUpdateOrganizationDomainEnrollmentMode` | R enrollment update checks mode, omitted/true/false delete-pending values and updated state. |
| `revokeOrganizationInvitationUsesOrganizationServiceRevokeOrganizationInvitation` | R revoke checks both organization and invitation IDs and revoked state. |
| `acceptUserOrganizationInvitationUsesOrganizationServiceAcceptUserOrganizationInvitation` | L exercises the generated user invitation's accept path and retains its public organization data. |
| `acceptOrganizationSuggestionUsesOrganizationServiceAcceptOrganizationSuggestion` | L exercises generated suggestion accept and published accepted status. |
| `acceptOrganizationMembershipRequestUsesOrganizationServiceAcceptOrganizationMembershipRequest` | R accept checks organization/request IDs and accepted state. |
| `rejectOrganizationMembershipRequestUsesOrganizationServiceRejectOrganizationMembershipRequest` | R reject checks organization/request IDs and rejected state. |

## Service declarations

R checks `_clerk_session_id`, the exact request path and effective method on successful mutations and paginated collections. Domain error cases additionally check code, message, normalized metadata, trace ID, absence of retry and unchanged projected state.

| Old declaration(s) | Replacement |
| --- | --- |
| `createOrganization`, `createOrganizationIncludesSlugWhenProvided` | R and existing organization creation tests check name, omitted/explicit slug and returned organization. |
| `getOrganization` | R separately fetched organization case checks fresh fields and isolation from the active root; existing lookup test checks ID and GET. |
| `updateOrganization`, `updateOrganizationOmitsSlugWhenNil` | R update cases inspect name and explicit/omitted slug. |
| `updateOrganizationPropagatesAPIErrors` | R update's 422 response preserves server error code/message in the structured failure; the native error shape replaces a directly thrown old `ClerkAPIError`. |
| `destroyOrganization` | R destroy checks effective DELETE on the organization path. |
| `setOrganizationLogo` | R binary upload checks the multipart host payload. The Apple HTTP capability suite checks multipart boundary/header and binary encoding. The shared test checks the host payload; it does not claim a live upload. |
| `deleteOrganizationLogo` | R receipt removal checks effective DELETE and a usable refreshed organization; the application return type intentionally changes from receipt to organization. |
| `getOrganizationRoles` | R roles page checks count, page 2 offset and migration flag. |
| `getOrganizationMemberships`, `getOrganizationMembershipsWithQuery`, `getOrganizationMembershipsWithRole` | R checks pagination marker, query and repeated role filters. |
| `addOrganizationMember`, `updateOrganizationMember`, `removeOrganizationMember` | R checks user IDs, role fields, membership paths and returned membership IDs/roles. |
| `getOrganizationInvitations`, `getOrganizationInvitationsWithStatuses` | R checks omitted empty filters and repeated pending/accepted values. |
| `inviteOrganizationMember`, `inviteOrganizationMembers` | R checks email field values, role and single/bulk returned IDs. |
| `createOrganizationDomain` | R checks domain name and organization path. |
| `getOrganizationDomains`, `getOrganizationDomainsWithEnrollmentMode` | R checks page offsets and enrollment filters. |
| `getOrganizationDomain` | R checks organization and domain IDs. |
| `getOrganizationMembershipRequests`, `getOrganizationMembershipRequestsWithStatus` | R checks collection offset/size and optional pending status. |
| `deleteOrganizationDomain` | R checks effective DELETE and the held resource after receipt. |
| `prepareOrganizationDomainAffiliationVerification` | R checks affiliation email and prepare path. |
| `attemptOrganizationDomainAffiliationVerification` | R checks verification code and attempt path. |
| `updateOrganizationDomainEnrollmentMode`, `updateOrganizationDomainEnrollmentModeOmitsDeletePendingWhenNil` | R checks enrollment mode and omitted/true/false delete-pending encoding. Canonical booleans serialize as `true`/`false`, replacing old `1`/`0`. |
| `organizationDomainMutationsPropagateAPIErrors` | All five old operations—create, prepare, attempt, enrollment update and delete—are covered by R's structured 422 cases. |
| `revokeOrganizationInvitation` | R checks organization/invitation IDs and resulting status. |
| `destroyOrganizationMembership` | M plus both packaged membership-deletion suites check the actual resource/client result contract. |
| `acceptUserOrganizationInvitation`, `acceptOrganizationSuggestion` | L checks both generated acceptance paths through native UI data sources. |
| `acceptOrganizationMembershipRequest`, `rejectOrganizationMembershipRequest` | R checks both paths and resulting statuses. |

## Validation and limits

The new shared suite has 47 cases; all 400 embedded tests pass. The three relevant source test files pass 12 tests. Runtime TypeScript compilation, generation (342 types, 1,551 members, zero unsupported shapes), and bundle/Expo attached-transport reproducibility checks pass.

The packaged native additions run six scenarios: logo receipt, complete organization response, delete rejection, refresh failure, separate fetched/updated resource, and empty invitation filters. Before rebuilding, five scenarios failed on both engines. After rebuilding, the full suites pass: macOS 85 tests in 14 suites, iOS Simulator 82 tests in 14 suites, Android 84 tests. Swift counts parameterized declarations once; the six scenario cases must not be interpreted as six additional declarations. Android's full run uses direct instrumentation and excludes only the separately opt-in live-startup and benchmark classes; comma-separated Gradle class filters were not used as proof of a full run.

The organization account-list model also passes seven Swift tests and two Compose instrumentation tests against this bundle. Generated preview fixtures now contain the distinct organization reference returned by collection hydration.

Both SDKs pin core `037bf3447780d13d757d077c6c6152372dabbe8c`, contract `0f8387f260072ba6f894442b73d50afa6bda5f1205ed3c9209f5d6b1cfba16ce`, and bundle SHA-256 `267191c1f5cfc44024a63a3d79f2534f8cf9f4666c2d58a6280feff4efeab8b6`.

No live organization server journey, OS browser/passkey prompt, physical-device performance budget, or actual old-major app upgrade is established by these deterministic checks. Those remain separate release gates. The default legacy test target still contains other unaudited old API files; this audit retires only the two files named above.
