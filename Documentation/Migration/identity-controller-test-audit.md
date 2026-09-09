# Identity controller assertion audit

Reviewed all twelve declarations and assertion bodies in the baseline
`Tests/Core/ClerkIdentityControllerTests.swift`. The file remains retained:
credential persistence and tokenless client rejection now have direct
embedded-core evidence. Credential-rotation fencing is also restored in the
shared transport. The retained sequences now have core regression tests; removed native staging
and shared-storage APIs below remain explicit migration differences.
This audit does not retire the file or claim parity with its assertions.

| Baseline declaration | Current disposition |
| --- | --- |
| `externalTransitionUsesAtomicPersistenceBeforeApplyingMemory` | Embedded `Session.reload` holds the credential write and checks that the visible session and call completion remain unchanged until persistence finishes. The old atomic client/date snapshot and external-transition API are removed; this proves credential-before-hydration, not persistence of the entire old snapshot. |
| `externalTransitionUsesLegacyPersistenceThroughSameBoundary` | The old synchronous transition and `didApply` callback are removed. Legacy credential import is audited separately in `keychain-test-audit.md`; runtime HTTP writes use the asynchronous shared boundary. |
| `failedExternalTransitionStageCannotExposeIdentity` | No external staging callback exists. Embedded credential-write failure leaves the active session and stored credential unchanged; a subsequent reload succeeds. Old staged publication failure is not separately reproduced. |
| `rejectedAtomicExternalTransitionRollsBackStagedState` | Private operation revisions, `stage`, `didApply`, and `didNotApply` are removed. Current generation/reset cancellation has separate tests; there is no replacement cross-process staging transaction. |
| `legacyMemoryResponsePathCannotBypassAtomicPersistence` | No public native client assignment or legacy response application exists. Held-write and failed-write embedded checks prove the current HTTP path cannot hydrate the returned session before successful credential persistence. |
| `atomicResponseRetainsOwnedCompletionAcrossOrdinaryRefreshUntilActivation` | The old registration/work/completion records are removed. Embedded tests verify sign-in and sign-up completion while another session stays selected, ordinary refresh with the server attempt retained or cleared, and explicit finalization selecting the created session. Both packaged native suites also reproduce and verify retention after a cleared server sign-in. |
| `atomicTokenOnlyResponseResolvesIdentityWhenItsSerializedTurnBegins` | An embedded test starts a session reload and token request, holds the first credential write, then queues the token-only reply. Completion preserves the newly accepted client ID and selected session while saving the rotated credential and returning the JWT. No whole-client storage snapshot is rewritten. |
| `atomicResponseRetryAfterPersistenceFailureKeepsResponseSequenceUsable` | Embedded credential-write failure preserves session/credential and permits a new reload that publishes the pending task. This covers public retry, not replay of the identical private response context. |
| `canonicalLegacyClientWithoutAClerkTokenIsRejected` | Reproduced and fixed in the shared transport. A client snapshot without a response or stored credential now fails with `missing_client_credential` before hydration. Embedded, packaged iOS and packaged Android tests first reproduced startup exposing an active fixture session; after repackaging they reject startup. Each also proves a restored credential permits the same headerless response. The non-native transport mode is unchanged. |
| `legacyResponseTokenRotationFencesOldTokenResponses` | Reproduced and fixed in shared TypeScript. Two reloads start with the same credential; the first persists a changed credential and publishes a pending task. The later-issued reply, despite a newer date, fails with `stale_client_request` and preserves the task/credential. Embedded, iOS and Android packaged tests check this sequence and subsequent reload recovery. Same-credential replies still use the independent date/sequence ordering rule. |
| `undatedAcceptedIdentityPreservesServerDateWatermark` | Shared transport preserves its date watermark when a response lacks a date. The old disk-client reload path and public fetch-date property are removed. The shared transport watermark test now covers both an older date and a missing date, then rejects the delayed response against the retained watermark. |
| `manualReloadStillAppliesLegacyClientAndEnvironmentWithoutCoordinator` | Manual live shared-storage reload, cached native environment decoding, and cross-owner identity replication are unavailable. Credential migration on startup does not replace these assertions. |

The persistence evidence is in
`javascript/packages/mobile-runtime/test/client-response-order.test.mjs`, using
the production embedded bundle and generated dispatch with controlled host
storage. The credentialless-client fix is pinned in the native bundles at
TypeScript commit `f64a85d7ac`, including the subsequent rotation fix. These checks do not prove
device Keychain behavior; the platform storage suites cover that separate host
boundary. The rotation rule is also grounded in backend source at
`clerk_go@33e0f8279c9b4e3d90d6e4788c67237bc6378a56`:
`api/fapi/v1/clients/service.go` describes rotating the token when client
sessions change; `api/shared/cookies/service.go` updates that token and its
serialized credential together. The new tests remain deterministic fixture
reproductions rather than live-account validation.

## Organization collection entry points

Both assertions in `Tests/Core/OrganizationsTests.swift` were also reviewed:
creation forwarded `My Org` with a nil slug, and lookup forwarded `org_123` to a
native service mock. The generated API now exposes `Clerk.createOrganization`
and `Clerk.getOrganization`. New embedded `organization.test.mjs` checks the
actual HTTP name/omitted-or-explicit-slug payload, requested organization path,
and returned generated organization ID/name. Those old mock collaborators are
removed. This is limited to the two collection entry points; the organization
service and resource test files still require their own assertion audit.

## Shared attempt ownership

Bundle pin `b9506775b3` routes identified mobile attempts through the existing
TypeScript resource signals, preserving completed attempts until finalization
even when a client refresh has cleared its server attempt field. Empty initial
attempts use the live client resource. The TypeScript state owner ignores late
updates from discarded attempts; client replacement, client destruction and
removal of all sessions retire retained authentication resources. Embedded tests
verify reset, client replacement and sign-out boundaries. No native auth-flow
registry or second state machine is added.
