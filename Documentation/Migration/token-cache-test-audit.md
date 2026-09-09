# Token cache and freshness assertion audit

All assertion bodies were reviewed in baseline `02f98f89a19b6c079517c9aae07df7edd0e600e5` for `Tests/Domains/Auth/TokenFreshnessTests.swift` and `Tests/Domains/Auth/Session/SessionTokenFetcherTests.swift`. The former has 14 declarations. The latter has 24 declarations, including a multiline parameterized declaration missed by the earlier file-level inventory's count of 23. Neither file is retired by this audit: the unresolved checks below still matter.

## Reproduced invalidation defect

The source cache ignored a settled request if its key was absent, but accepted it if a later request had recreated that key after `clearCache()`. Thus a pre-clear token could replace a post-clear token. A cache generation now prevents earlier requests from contributing to any entry created after a clear. Concurrent requests within one generation still preserve the shared freshness policy.

`packages/mobile-runtime/test/token-invalidation.test.mjs` tests the generated `Session.getToken({ template: 'firebase' })` and `Session.clearCache()` with two suspended HTTP requests. Both response orders fail before the fix and pass afterward. The original callers may receive their own responses; subsequent cache reads must retain the post-clear result without another request. The test deliberately gives the invalidated token a higher origin timestamp so invalidation cannot accidentally pass through timestamp ranking.

`NativeCoreContractTests/TokenInvalidationTests.swift` reproduces both failures using generated Swift calls on the old packaged JavaScriptCore bundle. The equivalent Android instrumentation checks reproduce both failures on QuickJS. These tests check cache behavior, not cancellation of the original callers or migration from a released app.

## Fetcher assertions

| Baseline declarations | Current owner, disposition, and limits |
| --- | --- |
| `fetchTokenUsesSessionServiceFetchToken`, `fetchTokenCachesFetchedToken` | `Session.getToken` owns request construction and caching in TypeScript. Template requests use `/sessions/{id}/tokens/{template}`; default requests include the organization field. The generated invalidation checks exercise template routing and a subsequent cache hit. Native private service invocation and a Swift `TokenResource` return are removed. |
| `templateTokenCacheIsPartitionedByActiveOrganization` | The TypeScript cache ID includes session, template, and organization. Its session tests cover explicit organization and template cache behavior. The old retained Swift value resolving the latest active organization is not independently reproduced here; generated wrappers read canonical resource state. |
| `invalidationPreventsInFlightResponseFromRestoringCachedToken`, `removeTokensRejectsWritesFromAnEarlierGeneration`, `clearRejectsWritesFromAnEarlierGeneration` | The new source and generated runtime tests cover cache-clear invalidation with a replacement entry, in both response orders. The removed private per-session `removeTokens` and snapshot `hydrate` entry points are not generated APIs. |
| `invalidatedInFlightTaskIsCancelledAndReplaced`, `completedRequestDoesNotClearReplacementTaskAfterReset` | Private task identities and a fetcher `reset` API are removed. Clear-cache replacement is verified, but the old promise-cancellation outcome is not claimed: a cache clear allows the original caller to receive its response. Explicit native cancellation is a separate runtime operation. |
| `retainedSessionDoesNotRehydrateInvalidatedSnapshot`, `nonActiveSessionDoesNotReturnExistingCachedToken`, `concurrentNonActiveSessionFetchesShareRequest` | The old tests continue fetching through a retained session after removing it from the client. The generated root handle instead becomes stale when removed, as checked by `session-state.test.mjs`. Nonselected but still available sessions and all token concurrency combinations need a separate execution audit. |
| `transitionedActiveSessionCanHydrateCanonicalSnapshot` | Session hydration and cache population belong to the source `Session`; the removed native snapshot hydration helper is not retained. The precise zero-request outcome after native invalidation is not claimed by this change. |
| `removeTokensClearsAllTokensForOnlyThatSession` | The old private per-session cache deletion is removed. The selected TypeScript `Session.clearCache()` delegates to the shared cache's full clear; it does not promise to retain other sessions' cached entries. |
| `storingSameJWTDoesNotReportCanonicalTokenChange` | The removed Swift cache's boolean change report is not public API. No equivalent native event-count guarantee is introduced. |
| `malformedIncomingTokenDoesNotReplaceCanonicalToken` | Malformed JWT parsing throws through the generated call (`token-decoding.test.mjs`). TypeScript cache entries with unusable claims are dropped so a later call refetches; the old helper's exact fallback result is not preserved. |
| `hydrationDoesNotReplaceCanonicalTokenOnTimestampTie`, `hydrationAcceptsStrictlyFresherSessionSnapshot`, `hydrationPreservesFresherExpiredTokenForNextMint` | Source session hydration and last-active-token freshness are authoritative. Source tests cover fresher/staler touch responses and future mint inputs. The old hydration-only tie rule and exact expired native-cache fallback are not claimed as equivalent. |
| `sessionMinterUsesLatestSessionTokenAndForcesOrigin`, `sessionMinterOmitsPreviousTokenOnFirstMint`, `disabledSessionMinterDoesNotPassTokenOrForceOrigin` | Source session tests verify the minter flag, previous-token body, forced-origin option, and first mint. No second native minter policy is added. |
| `concurrentForcedRefreshesCannotRollBackCanonicalToken` | Source session tests cover both resolution orders, each caller's own token, the freshest cached result, last-active token, and the next mint's input. The new invalidation fence preserves ranking within the same cache lifetime. |
| `resetCancelsConcurrentForcedRefreshes`, `cancellingCallerCancelsForcedRefresh` | The private native fetcher reset disappears. Runtime cancellation and owner teardown are covered separately, but cancellation of coalesced token requests, background refresh, and subsequent recovery remain specific checks to complete. |

## Freshness assertions

| Baseline declarations | Canonical behavior |
| --- | --- |
| `keepsTokenWithHigherOriginIssuedAt`, `usesIssuedAtToBreakEqualOriginIssuedAt`, `acceptsIncomingTokenOnFullTimestampTie`, `treatsTokenWithoutOriginIssuedAtAsOlder` | Covered by source `tokenFreshness.test.ts`: compare origin timestamp, then issued-at, accepting the incoming token on a full tie. |
| `usesIssuedAtWhenBothTokensLackOriginIssuedAt` | Intentional difference: the existing TypeScript helper accepts the incoming token when both lack the origin timestamp; its legacy-token test records this policy. |
| `keepsExistingTokenOnFullTimestampTieWhenRequested` | The Swift-only tie-break option is removed. The canonical helper has no such option. |
| `acceptsIncomingTokenWhenOrganizationChanges`, `acceptsOrganizationChangeBeforeComparingExpiration` | Source `shouldKeepExistingLastActiveToken` compares freshness only within the same session and organization. The source session test checks that an organization switch accepts the new organization's token even with a lower origin timestamp. |
| `replacesExpiredExistingToken`, `keepsUnexpiredExistingToken`, `comparesFreshnessWhenBothTokensAreExpired` | Expiration belongs to TypeScript cache validity and timers, not its timestamp comparison helper. Source cache tests cover expiry and remaining lifetime. The old Swift comparator's precedence rules are removed. |
| `keepsDecodableExistingTokenWhenIncomingCannotBeDecoded`, `acceptsDecodableIncomingTokenWhenExistingCannotBeDecoded`, `acceptsIncomingTokenWhenNeitherTokenCanBeDecoded` | The private Swift decoder/comparator fallback is removed. Generated token requests reject malformed JWTs and the source cache rejects unusable claims. No native helper silently chooses malformed tokens. |

## Evidence and remaining work

The fix passes all 229 embedded-core tests and 195 focused source tests across `Session`, `tokenCache`, and `tokenFreshness`. The full native contract suite passes 69 tests on macOS and 66 on iOS Simulator; both Android invalidation tests pass. The packaged core is pinned to `35639cd01a43caced4eb948891e404bff43271dd`, SHA-256 `0282374e1419ee72a7e8718fa7bd2936442e00f92dbecf125262f13b55462549`; generated public signatures are unchanged.

This audit does not establish cancellation behavior for multiple callers sharing one token request, all old snapshot-hydration semantics, live service behavior, or signed-in old-major upgrades. The legacy files remain available for those follow-up checks. Native token/session policy remains in TypeScript throughout.

## Proactive refresh follow-up

The initial fix fenced requests already registered with the cache. Proactive refresh instead calls `set` after its HTTP response, so it could restore a cleared cache or overwrite a replacement token, and update the last-active token. Both cases were reproduced in the source and generated embedded tests. The refresh now captures the cache generation when it starts and discards its token after a clear. In-flight refresh tracking also records that generation, so an older request neither blocks the new lifetime's refresh nor releases its marker when it finishes.

The source tests exercise both cache outcomes and overlap between two cache lifetimes, including a later timer coalescing with the current refresh. Native `clearCacheRejectsAProactiveRefresh` checks both empty and repopulated caches. It explicitly foregrounds the fixture runtime, advances one host refresh timer, and lets the suspended response settle before reading the token through the generated API. Both cases failed on the prior packaged core; these are controlled host fixtures, not real OS suspension evidence. Token checks share the lifecycle tests' serialized `PackagedCoreTests` suite because those tests post process-wide active/inactive notifications.

The shared follow-up passes all 231 embedded-core tests and 198 focused token/session source tests. Full native contract suites pass 70 tests on macOS and 67 on iOS Simulator. Android passes four token invalidation tests and 11 packaged-core tests in separate runs. Its packaged revision is `750f50cf8b67f6251c3b5a4776d87cc90be680a8`, SHA-256 `fc41a7eee1663d8cc2016d3f1cc52fcca92fc58f68c1e5416a5a441406c05e59`. Public generated signatures remain unchanged.
