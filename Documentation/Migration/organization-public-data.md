# Organization invitation and suggestion projection

An organization invitation with a null image URL failed with `invalid_projection:UserOrganizationInvitation.publicOrganizationData`. An omitted slug could cause the same failure. Organization suggestions used the same unchecked assignment and had the same issue. This was found while reviewing the retained organization serialization tests.

The shared TypeScript resource implementations now normalize null or omitted `image_url` to an empty string and null or omitted `slug` to null. Existing image URLs, slugs, organization IDs, names and image flags remain intact. Generated public types remain unchanged. The fix does not add a native domain model or platform-specific response parser.

Eight shared cases cover invitations and suggestions with present branding, null branding, omitted branding, and a null image plus omitted slug. Six failed before the change; all eight pass afterward. Invitation metadata preserves objects, nested nulls and numbers. Millisecond creation dates and ISO-formatted update dates survive resource hydration and projection. Each generated listing makes one request and preserves the selected user/session.

The packaged Kotlin and Swift tests exercise the same eight cases through the actual QuickJS and JavaScriptCore bundles. They use fixture HTTP, not a live backend. [The proof](evidence/organization-public-data/proof.json) records source and bundle hashes, exact Android case names, Swift results and iOS Simulator results.

Both SDKs package JavaScript revision `4c7c77f5b7e5d52b0c4e65ce8b59b8854e956972`, bundle SHA-256 `d0142b55cfa80ef2e7d5769ae95e460b9c798fa451b9f3fc5eef78d63652a6bd`. The generated API bytes still match the generator output.

## Remaining timestamp assertion

The old `UserOrganizationInvitationTest.kt` also expects numeric epoch seconds to be multiplied by 1,000. A direct generated-runtime probe confirms that the selected TypeScript implementation treats numeric dates as milliseconds: `1713200000` becomes a date in January 1970, while `1713200000000` and the supplied ISO date produce their expected 2024 dates. This fix does not change timestamp interpretation. The old file remains retained while that compatibility difference is resolved; this is not claimed as completed assertion retirement.

The [published Frontend API schema](https://github.com/clerk/openapi-specs/blob/a91bd1815277a236107ef325be6e138db32762cb/fapi/2026-05-12.yml#L16189-L16196) declares both invitation dates as `int64` Unix timestamps without specifying units. Its user-context invitation inherits those fields. [The schema review](evidence/organization-public-data/schema-review.json) pins the source revision and file hash. This is insufficient evidence to change the mature shared date parser or to claim that the old seconds assertion matches the backend contract.

## Verification notes

The full shared suite passes 596 tests on recheck, with zero failures or skips. The first broad run reported failure of `selected-code-factors.test.mjs` without an assertion diagnostic; its 13 tests passed in isolation, and the complete rerun passed with TAP output. The first failure log is preserved without attributing an unproven cause. The 82 focused organization/user-resource checks also pass.

The native test fixture initially tried to share a single nominal data type between invitations and suggestions. The generator intentionally gives these shapes distinct names; the test now compares their exposed fields. Both native suites compiled and passed after correcting that test setup. No generated type was changed.

The same shared bundle also passed Android [test CI](https://github.com/clerk/clerk-android/actions/runs/34549087195) and [release-build CI](https://github.com/clerk/clerk-android/actions/runs/34549089302) at Android revision `e69c39e46f25cebb3680525e9ea23439cd1674a8`: 168 emulator cases including all eight organization cases, 566 unit tests, and two byte-identical AARs with the expected bundle. This supplements the Swift and iOS Simulator results above.
