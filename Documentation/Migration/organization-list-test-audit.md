# Organization account list migration audit

All ten declarations in baseline `Tests/Domains/Organization/OrganizationAccountListDataSourceTests.swift` were reviewed. Their presentation behavior is now checked in `Tests/UI/OrganizationAccountListCoreTests.swift` through generated resources executing the packaged JavaScriptCore bundle. The old dependency-container and native service mocks are removed with that legacy test file. The separate Organization and OrganizationService suites are now retired under the [organization resource audit](organization-resource-test-audit.md). OrganizationCreationDefaults is now retired under its [own assertion audit](organization-defaults-test-audit.md).

## Pagination regression

With two pending invitations visible and a third on the server, accepting the first leaves one visible pending invitation. The migrated pager still requested page two with a page size of two, skipping the third invitation. The generated UI test reproduced the missing row, incorrect visible statuses, and unfinished pagination before the fix.

The pager now derives the next whole page from the count still represented in the server collection. A partial page is fetched again, and already displayed resource handles are omitted from the appended rows. Accepted invitations remain visible while no longer contributing to the pending offset. The same pager serves memberships, invitations, suggestions, membership requests, and domains. Existing list callers pass their page size explicitly; they do not invent fractional page values or a second resource API.

## Assertion map

| Legacy test | Replacement evidence |
| --- | --- |
| `testLoadInitialFetchesResourcesAndCreationDefaults` | Generated collection requests verify page size, first offset, pending invitation filter, and pending/accepted suggestion filters. Returned memberships, invitations, suggestions, and all creation-default fields reach the data source. |
| `testLoadInitialTracksEmptyState` | Empty generated responses finish loading, expose no rows or next page, and omit the defaults request when disabled. |
| `testLoadInitialClearsLoadingStateAfterFailure` | A 500 response exposes an error and clears loading; a subsequent successful load clears the error. |
| `testLoadMoreMembershipsUsesCurrentOffset` | A partial first response followed by load-more returns both members once and completes pagination. Whole-page requests may overlap the current page; exact legacy offset=1 serialization is intentionally replaced by canonical page parameters and duplicate filtering. |
| `testPagerLoadedPageOffsetsRepresentCurrentLoadedWindow` | Real generated membership pages preserve the empty/one/two/three-page revalidation offsets. |
| `testPagerReplaceWithPagesPreservesLoadedWindowAndPagination` | Replacing the loaded window with two generated pages retains 20 rows, total count 21, and the next-page indication; the next generated fetch returns the final member. |
| `testAcceptInvitationMarksInvitationSelectableAndAdjustsPagination` | The single-invitation case retains an accepted row with zero pending offset/count and no next page. |
| `testAcceptInvitationKeepsPublicOrganizationDataWithoutFetchingOrganization` | Accepted resources preserve the public organization ID without fetching a full organization. |
| `testAcceptInvitationKeepsAcceptedRowAndUsesPendingOffsetForNextPage` | Three- and eleven-invitation cases retain the accepted row, fetch the remaining pending row, avoid duplicates, and finish pagination. |
| `testAcceptSuggestionReplacesSuggestionWithAcceptedVersion` | The generated accept call preserves the suggestion row and publishes its accepted status. |

The replacement suite has seven declarations with three parameter cases for invitation counts. These are native data-source and packaged-engine checks with deterministic service responses; they do not establish a live organization acceptance or a visually inspected device journey.

Validation passes the full macOS UI suite (145 tests) and iOS Simulator UI suite (156 tests). The final seven-test focused suite also passes after adding explicit checks for every creation-default field. The packaged core remains revision `ea3c1dd6d3ba43f411f2152566d35640a1038104`; this fix changes presentation pagination, not domain behavior or generated APIs.
