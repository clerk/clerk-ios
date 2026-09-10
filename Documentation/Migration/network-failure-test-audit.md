# Network failure and retry assertion audit

Baseline: `02f98f89a19b6c079517c9aae07df7edd0e600e5`. All assertions in `ClerkRateLimitRetryMiddlewareTests.swift` (ten declarations) and `ClerkInvalidAuthResponseMiddlewareTests.swift` (one declaration) were reviewed. Their hashes and declaration names match [the inventory](legacy-tests.json). Exactly these two legacy files are retired after the replacement checks below; the mixed API client, header, credential and client-sync suites remain retained.

## Reproduced recovery defect

A generated `Session.reload()` receiving HTTP 401 calls the core's unauthenticated recovery, which fetches `/client`. When that fetch also returned 401, the common request handler started the same recovery again. The reproduction bounded the broken loop by returning 403 on the fourth client read; without that fixture stop, each rejected refresh could start another refresh. The old bundled Apple and Android engines both reached four reads instead of the expected startup read plus one recovery read. The artificial 403 also cleared the selected session.

The shared `BaseResource` handler now lets an unauthorized GET `/client` report its error without invoking another client refresh. Other unauthorized resource requests still invoke the existing recovery path. The `dev_browser_unauthenticated` and `requires_captcha` branches are unchanged. This is one TypeScript fix; neither native host implements recovery policy.

`network-failure.test.mjs` verifies that the rejected refresh terminates, preserves the last accepted session in the absence of a replacement response, and permits a subsequent successful request. It also checks two concurrent unauthorized operations: each performs its own bounded recovery request. The canonical core does not promise the old private Swift refresh coalescing behavior. `NetworkFailureTests.swift` and Android `NetworkFailureTest.kt` reproduce and verify the same terminating error, session identity and subsequent reload through generated APIs and actual packaged engines.

## Canonical retry behavior

The source `fapiClient` retries rejected GET fetches, with one immediate retry and then exponential backoff. The default online limit is four fetch attempts; the offline/request-option policies remain owned by the existing core. Mutation requests are not replayed at this transport layer. A received HTTP 4xx/5xx response is interpreted as an API result and is not a failed fetch eligible for that transport retry. Higher-level token, startup or authentication flows may have their own shared retry policy.

Sixteen generated-call tests cover a transient GET failure recovering on its second fetch with a retry query marker and unchanged authorization; a persistent GET failure stopping at four attempts; a failed authentication mutation reporting an error without a second submission; eleven HTTP statuses surfacing without replay; and the two unauthorized recovery scenarios above. The persistent-failure fixture advances host timers without real backoff waits. It proves the attempt limit, not wall-clock delay accuracy. Failure strings and the old `URLError.Code` classification are not public native retry controls.

| Old declaration | Current behavior / intentional policy change |
| --- | --- |
| `shouldRetryForRateLimit429` | Generated `Session.reload` reports HTTP 429 after one request, even when Retry-After/reset headers are present. No native automatic replay. |
| `shouldRetryForServerError500` | Generated HTTP 500 case reports the error after one request. No native status retry. |
| `shouldRetryForRetryableStatusCodes` | All seven old statuses (408, 425, 429, 500, 502, 503, 504) have generated request/error cases. They are no longer retryable at the transport layer merely because of their status. |
| `shouldNotRetryForNonRetryableStatusCodes` | Generated 400, 403, 404 and 422 cases report one response. The separate 401 cases check one bounded client recovery per failed operation, rather than replaying the rejected session request. |
| `shouldNotRetryOnSecondAttempt` | The old one-retry limit is removed. Transient GET failure succeeds on attempt two; persistent failure stops after four total online attempts. Authentication mutation failure is submitted once. |
| `retryDelayFromRetryAfterHeader` | The removed middleware slept about two seconds before replaying 429. The generated 429 case does not replay. Structured `retryAfter` remains available to callers under the [error audit](error-test-audit.md); it is not an automatic native scheduler. |
| `retryDelayFromXRateLimitResetHeader` | No native reset-header delay calculation remains. The generated status cases include the header and still report the response once. |
| `retryDelayDefaultsToHalfSecond` | No default 500 ms native retry delay remains. The canonical GET fetch policy owns its immediate retry and subsequent backoff. |
| `shouldRetryForRetryableURLErrors` | Native hosts report failed HTTP execution; TypeScript decides whether the operation can be retried. Generated transient/persistent GET failures and a non-replayed authentication mutation check those outcomes. The six old Swift error-code cases are not independently classified by a second algorithm. |
| `shouldNotRetryForNonRetryableURLErrors` | The native error-code allow/deny list is removed. Bad input and cancellation are handled at their current host/bridge boundaries; this audit does not claim the old arbitrary `URLError` injection has the same retry decision. |
| `coalescesConcurrentInvalidAuthRefreshes` | The old test called a private refresh method twice and expected one mocked service call. That method/service are removed. Generated concurrent unauthorized operations each perform one recovery read and both finish with structured 401 errors. Coalescing is not promised by the selected canonical implementation. |

## Validation

Shared core: `cd3b7a30cc50c9afd731f181a6b20d681755b713`. Both native packages carry bundle SHA-256 `a366249b593f33a00ef9eaa541fffe8f068b1f271a4fd91aa6b089a75a288e70` with the existing binding contract unchanged.

All 539 embedded runtime tests pass. The relevant BaseResource, Client and fapiClient source suites pass 62 tests, with one existing skipped test and four existing TODO cases. TypeScript checking, generated-artifact checking and bundle reproducibility pass. The complete native contract suites pass 104 tests on macOS, 101 on iOS Simulator and 112 on Android, including the new regression. The Android run excludes only the separately opt-in benchmark and live-startup classes.

These fixtures prove generated-call behavior, bounded recovery and native error delivery. They do not establish live network interruption timing, backend availability, every operation-specific retry policy, or the retained blank-Bearer clear and shared identity retry contracts.

The subsequent [request retry audit](request-retry-test-audit.md) covers obsolete identity checks before fetch attempts and the Android fractional-timer defect found by real packaged retries.
