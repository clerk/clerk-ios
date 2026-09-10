# Client response and ordering assertion audit

Reviewed the complete assertion bodies of the baseline
`Tests/Core/ClerkResponseClientStateTests.swift` (27 declarations) and
`Tests/Core/ClientResponseOrderingGateTests.swift` (six declarations), together
with the baseline `ClientResponseOrderingGate` implementation. This is separate
from the identity controller audit and the retained `ClerkTests` suite.

## Shared ordering behavior

The audit reproduced a regression through generated `Session.reload()`: a newer
response published a pending organization task, then an earlier delayed reply
restored active state and overwrote the credential. It failed in the embedded VM
and in the packaged Swift and Kotlin SDKs before the shared fix.

The pinned TypeScript mobile credential transport now rejects that response
before persistence and FAPI hydration. It assigns request sequences, accepts
newer request sequences, and accepts older/equal sequences only with a newer
server date or a tied date plus newer client version. Accepted sequence and date
watermarks do not regress. Authentication invalidation starts a new date history
while still rejecting old-generation requests. No native ordering gate is
retained. Missing/invalid dates cannot prove that an older request has newer
state. Resource-only responses without a client snapshot are outside this rule.

Credential changes have a separate, stronger fence: after a changed credential
is persisted, replies issued with the previous credential cannot commit a client
snapshot or credential, even with a newer sequence/date. See the
[identity controller audit](identity-controller-test-audit.md). The date-ordering
fixtures repeat the existing credential so they exercise timestamp/sequence
ordering independently of rotation.

The embedded ordering tests cover direct client refresh, both `client` and
`meta.client` piggybacks, date/version precedence, missing/invalid dates, reset,
preserved tasks and credentials, and a usable resource after rejection. Shared
transport tests cover the non-regressing date watermark. The native
`olderClientResponseCannotRemoveANewerPendingTaskOrCredential` test exercises the
same result through real JavaScriptCore and QuickJS with fixture HTTP/storage.

## Response-state declarations

| Baseline declaration | Disposition |
| --- | --- |
| `applyResponseClientSetsFirstClient` | Real packaged startup hydrates the first server client; generated `clientId`, sessions and auth roots expose its selected state. |
| `applyResponseClientWithoutSequenceReplacesExistingClient` | Direct native client assignment is removed. The session-state replacement case checks a changed server client ID, retirement of the old selected session, and no implicit adoption of a newly listed replacement. |
| `applyResponseClientAcceptsNewerResponseSequenceEvenWhenUpdatedAtIsOlder` | Shared transport watermark test accepts a newer request even with an older date and client version. |
| `applyResponseClientIgnoresOlderResponseSequenceEvenWhenUpdatedAtIsNewer` | Missing/invalid server-date cases reject the older request even when its client version is higher. Current task and credential remain intact. |
| `applyResponseClientDoesNotRegressServerDateWatermark` | Shared transport test accepts the newer request with an older date, then rejects a delayed request whose intermediate date must not exceed the retained watermark. |
| `applyResponseClientAcceptsOlderResponseSequenceWhenServerDateIsNewer` | Embedded ordering case accepts the older request's newer server state. Native `auth.events` is removed; task/session projection replaces its event assertions. |
| `applyResponseClientAcceptsOlderResponseSequenceWhenServerDateTiesAndClientUpdatedAtIsNewer` | Embedded ordering case preserves that tie-break rule and publishes the accepted session. |
| `applyResponseClientNilIgnoresOlderResponseSequence` | The arbitrary `applyResponseClient(nil, ...)` mutation is removed. Generated sign-out and authentication invalidation fence late requests; an empty unrelated HTTP response is not an instruction to clear the client. |
| `applyResponseClientStoresServerDate` | The native `lastClientServerFetchDate` property is removed. Server dates remain internal ordering metadata, checked through their acceptance outcome. |
| `applyResponseClientDoesNotEmitContinuationForResumableSignIn` | The old global event/continuation API is removed. Generated verification tests expose `needs_second_factor` without implicitly adopting a session. |
| `applyResponseClientDoesNotEmitContinuationForResumableSignUp` | The old continuation API is removed. Sign-up requirements and explicit finalization are core-owned; they are not inferred from a native event. |
| `applyResponseClientDoesNotEmitContinuationWhenResumableSignInIsUnchanged` | No native continuation is synthesized on client application. The old event-count assertion retires with that API. |
| `organizationReturnsActiveSessionOrganization` | Embedded session-state tests and native `sessionReloadPublishesOrganizationSelectionBeforeCompletion` check organization ID/name and membership ID, then selection changes after reload. `clerk.organizationMembership` is removed; use the user's generated memberships. |
| `organizationReturnsNilWhenSessionHasNoActiveOrganization` | Embedded tests cover personal mode and unmatched organization IDs; native reload into personal mode clears the selected organization while preserving the membership list. |
| `cleanupManagersResetsLastAppliedClientResponseSequence` | The public cleanup/reuse and callback-continuation APIs are removed. Close makes an owner terminal; reconnect creates another. The embedded auth-reset test verifies a new date history without signing out the retained session. |

## Watch declarations

All twelve declarations below test live watch synchronization, which is
explicitly unavailable in this prerelease. Credential import is not a
replacement for watch convergence. Their assertions are recorded as unavailable
behavior, not passing coverage:

| Declaration | Unavailable behavior |
| --- | --- |
| `watchReducerCanApplyAuthoritativeIncomingState` | Phone-authoritative replacement overrides local client/sequence state. |
| `watchReducerAuthoritativeNilClearsClient` | Phone-authoritative nil clears the watch client. |
| `nonAuthoritativeWatchSyncRefreshesInsteadOfReplacingActivePhone` | Watch input schedules server reconciliation while preserving phone identity/date. |
| `nonAuthoritativeWatchSyncSameVersionRefreshesWhenLocalVersionExists` | Equal-version watch input causes a server refresh. |
| `nonAuthoritativeWatchSyncKeepsPhoneClientWhenServerFetchDateIsOlder` | Older watch state cannot overwrite an active phone identity. |
| `nonAuthoritativeWatchSyncSchedulesRefreshWhenNoServerFetchDates` | Missing-date watch state defers to server refresh. |
| `nonAuthoritativeWatchSyncNilDoesNotClearPhoneClient` | Non-authoritative nil cannot sign the phone out. |
| `nonAuthoritativeWatchSyncClearDoesNotPublishStalePhoneClientAsCleared` | A watch clear cannot relabel the retained phone snapshot or advance its clear metadata. |
| `nonAuthoritativeWatchSyncSeedsPhoneWhenNoLocalClient` | A watch snapshot can seed an empty phone identity. |
| `nonAuthoritativeWatchSyncNilDoesNotSeedPhone` | Nil watch input does not seed a phone identity. |
| `nonAuthoritativeWatchSyncClearRecordsVersionWhenLocalAuthIsEmpty` | Empty-phone clears retain a version that fences older snapshots. |
| `nonAuthoritativeWatchSignInWithLowerVersionRefreshesPhone` | An older watch sign-in triggers server reconciliation without directly adopting its snapshot. |

## Ordering helper declarations

`rejectsOlderSequenceWithoutNewerServerState`,
`acceptsOlderSequenceWithNewerServerDate`, and
`equalServerDateUsesClientUpdatedAt` are covered by the embedded HTTP ordering
cases. `recordDoesNotRegressServerDateWatermark` is covered by the shared
transport credential outcome. `resetClearsOrderingWatermarks` is covered by the
embedded authentication-reset date-history case. The private
`resetSequencePreservesServerWatermark` operation is removed: there is no
independently mutable native sequence counter in the generated SDK.

These tests prove deterministic response handling with fixture server metadata.
They do not establish real server clock/version behavior, signed-in app upgrade
continuity, or live shared-session/watch synchronization.

The two reviewed legacy files are retired after this audit and passing shared
and native replacement checks. Their baseline names and assertions remain
traceable through the test inventory. The identity controller suite is retired
under its own assertion audit; the general core suite remains in place.
