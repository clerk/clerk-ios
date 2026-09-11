# Organization state and presentation assertion audit

Four Android legacy files contain eight declarations: `OrganizationCreationDefaultsTest.kt` (one), `OrganizationDomainTest.kt` (three), `OrganizationMembershipTest.kt` (two), and `ClerkOrganizationTest.kt` (two). Each file matched baseline `1ea9f97250e9e3b266b7fbcfe37d9373e4fc393f` byte for byte before retirement. The [proof](evidence/organization-state/proof.json) preserves every declaration and source hash. This retirement changes the Android inventory; it does not claim to retire any iOS legacy test file.

The selected TypeScript resources own defaults, membership permissions, domain hydration and active-organization selection. Native APIs expose generated resource relationships and values. The tests added here run those values through the real packaged JavaScriptCore and QuickJS engines. No native parser, domain model, permission registry or organization selector was introduced.

## Every legacy declaration

| Old declaration | Current behavior and evidence |
| --- | --- |
| `decodes partial organization creation defaults` | The shared, Swift and Kotlin partial-branding cases preserve the advisory code, both metadata values, name and non-null logo URL. Missing slug becomes the canonical empty string, replacing the old nullable DTO field. Existing absent-form, absent-severity and absent-slug cases still pass. |
| `enrollmentModeType maps known enrollment modes` | Packaged domain cases verify the typed manual-invitation, automatic-invitation and automatic-suggestion cases and their exact wire strings. Enterprise SSO is checked as an additional selected TypeScript case. |
| `enrollmentModeType preserves unknown enrollment modes` | Both native engines return the generated unrecognized case with `future_mode` intact. The same case preserves an unknown verification status. |
| `isVerified reflects verification status` | Packaged resources preserve verified, unverified and null verification, including the affiliation-verification alias. UI tests require verified status alone; failed, expired, unknown and absent verification all remain false. |
| `permission helpers read raw and system permission keys` | Packaged membership cases preserve the custom key and all ten legacy system keys. The generated API exposes `permissions`; the old public enum and convenience methods are removed. The six helpers used by native UI are tested one grant at a time, so a permission for one action cannot enable another. Billing and API-key grants remain available as raw list entries without restoring four old convenience aliases. |
| `permission helpers return false for missing permissions` | The shared owner normalizes null or omitted permission fields to an empty list. Packaged tests verify that normalization. UI tests require all six actions to stay disabled for an empty list or an unrelated custom grant. |
| `organizationMembership returns membership matching active organization id` | Two memberships are supplied with the active one second. Both packaged engines require `clerk.organization` to be that same generated organization instance. The current user and session retain identity. Android switcher tests check loaded memberships and the user-membership fallback. The removed `Clerk.organizationMembership` property is replaced by traversal through `user.organizationMemberships`. |
| `organizationMembership returns null when no active organization id exists` | Both packaged engines preserve the user and both memberships while exposing no active organization. An additional unmatched-ID case proves that no arbitrary membership is selected. |

## Verification and limits

Fifteen focused shared cases and the complete 608-case shared rerun pass with no skipped cases. Android passes 11 state cases and four defaults cases on the emulator; seven UI tests check permission gating, verification status and switcher selection. The iOS Simulator ran and passed all 15 named state/defaults parameter cases. Swift UI tests also pass eight permission scenarios and six verification scenarios using generated resources backed by the packaged engine.

The final Swift package run reports 282 tests in 41 suites and succeeds. Two live-integration tests remain skipped because `with-email-codes` credentials are not configured; the new organization cases are not skipped. These are deterministic fixture-HTTP checks, not a claim of live-backend verification or rendered organization-screen coverage.

The first broad shared run crashed the existing `magic-link.test.mjs` Node v24.15.0 process with `SIGSEGV`. The matching macOS crash report locates the fault in V8 garbage collection. Root cause is undetermined. All 40 magic-link cases then passed in isolation, and the unchanged full-suite command passed all 608 cases. Both logs and a minimal crash summary are preserved in the proof directory.

Production sources, generated APIs and packaged core bytes are unchanged. Both SDKs still package JavaScript revision `4c7c77f5b7e5d52b0c4e65ce8b59b8854e956972` with bundle SHA-256 `d0142b55cfa80ef2e7d5769ae95e460b9c798fa451b9f3fc5eef78d63652a6bd`. Android CI selection now includes all 15 organization state/defaults cases. The separate [invitation timestamp difference](organization-public-data.md#remaining-timestamp-assertion) remains open; its legacy file is retained.

## Generated API examples

```swift
let defaults = try await user.getOrganizationCreationDefaults()
let suggestedSlug: String = defaults.form.slug
let activeID = clerk.organization?.id
let activeMembership = clerk.user?.organizationMemberships.first {
  $0.organization.id == activeID
}
let canReadBilling = activeMembership?.permissions.contains("org:sys_billing:read") == true
```

These expressions read the core's projected state. Permission checks do not create or infer grants from the role name.
