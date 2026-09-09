# Identity controller assertion audit

Reviewed all twelve declarations and assertion bodies in the baseline
`Tests/Core/ClerkIdentityControllerTests.swift`. The file remains retained:
credential persistence now has direct embedded-core evidence, but tokenless
client acceptance and credential-rotation fencing are unresolved differences.
This audit does not retire the file or claim parity with its assertions.

| Baseline declaration | Current disposition |
| --- | --- |
| `externalTransitionUsesAtomicPersistenceBeforeApplyingMemory` | Embedded `Session.reload` holds the credential write and checks that the visible session and call completion remain unchanged until persistence finishes. The old atomic client/date snapshot and external-transition API are removed; this proves credential-before-hydration, not persistence of the entire old snapshot. |
| `externalTransitionUsesLegacyPersistenceThroughSameBoundary` | The old synchronous transition and `didApply` callback are removed. Legacy credential import is audited separately in `keychain-test-audit.md`; runtime HTTP writes use the asynchronous shared boundary. |
| `failedExternalTransitionStageCannotExposeIdentity` | No external staging callback exists. Embedded credential-write failure leaves the active session and stored credential unchanged; a subsequent reload succeeds. Old staged publication failure is not separately reproduced. |
| `rejectedAtomicExternalTransitionRollsBackStagedState` | Private operation revisions, `stage`, `didApply`, and `didNotApply` are removed. Current generation/reset cancellation has separate tests; there is no replacement cross-process staging transaction. |
| `legacyMemoryResponsePathCannotBypassAtomicPersistence` | No public native client assignment or legacy response application exists. Held-write and failed-write embedded checks prove the current HTTP path cannot hydrate the returned session before successful credential persistence. |
| `atomicResponseRetainsOwnedCompletionAcrossOrdinaryRefreshUntilActivation` | The old registration/work/completion records are removed. Generated future resources retain explicit finalization, but this exact competing-session refresh sequence still needs a current-resource regression test. |
| `atomicTokenOnlyResponseResolvesIdentityWhenItsSerializedTurnBegins` | New storage contains the credential, not a serialized client snapshot, so token-only writes cannot rewrite a persisted client field. The queued token-only response sequence still needs a direct core test; absence of that field is not a concurrency proof. |
| `atomicResponseRetryAfterPersistenceFailureKeepsResponseSequenceUsable` | Embedded credential-write failure preserves session/credential and permits a new reload that publishes the pending task. This covers public retry, not replay of the identical private response context. |
| `canonicalLegacyClientWithoutAClerkTokenIsRejected` | Unresolved difference. A controlled startup with no authorization header on either environment or client responses, and no saved credential, currently reports an active fixture session. The old implementation rejected its canonical client. |
| `legacyResponseTokenRotationFencesOldTokenResponses` | Unresolved difference. Two reloads issued with the same credential can both succeed after the first rotates it: the second, later-sequence response can replace the first response's pending state. Current generation changes only on explicit invalidation/disposal. Reconcile this with real shared JS credential-rotation semantics before selecting a fix; timestamp ordering alone does not cover the old rule. |
| `undatedAcceptedIdentityPreservesServerDateWatermark` | Shared transport preserves its date watermark when a response lacks a date. The old disk-client reload path and public fetch-date property are removed. Existing watermark coverage uses an older dated response; an undated-response regression remains to add. |
| `manualReloadStillAppliesLegacyClientAndEnvironmentWithoutCoordinator` | Manual live shared-storage reload, cached native environment decoding, and cross-owner identity replication are unavailable. Credential migration on startup does not replace these assertions. |

The persistence evidence is in
`javascript/packages/mobile-runtime/test/client-response-order.test.mjs`, using
the production embedded bundle and generated dispatch with controlled host
storage. These new checks require no native bundle change. They do not prove
device Keychain behavior; the platform storage suites cover that separate host
boundary. The two observed differences above are fixture reproductions, not
claims about live server responses.

## Organization collection entry points

Both assertions in `Tests/Core/OrganizationsTests.swift` were also reviewed:
creation forwarded `My Org` with a nil slug, and lookup forwarded `org_123` to a
native service mock. The generated API now exposes `Clerk.createOrganization`
and `Clerk.getOrganization`. New embedded `organization.test.mjs` checks the
actual HTTP name/omitted-or-explicit-slug payload, requested organization path,
and returned generated organization ID/name. Those old mock collaborators are
removed. This is limited to the two collection entry points; the organization
service and resource test files still require their own assertion audit.
