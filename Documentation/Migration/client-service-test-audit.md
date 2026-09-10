# Client service assertion audit

All assertion bodies were reviewed in baseline `02f98f89a19b6c079517c9aae07df7edd0e600e5` for `Tests/Domains/Client/ClientServiceTests.swift` (two declarations) and `ClientTests.swift` (ten). These files are retired with the removed native client service after the checks below. The public native `refreshClient`, mutable client/credential properties, and `updateDeviceToken` entry points are removed in the new major; automatic foreground and connectivity recovery remain core-owned.

## Empty response defect

The old service explicitly maps a null `response` to `ClientServiceUpdate.preserve`. The shared resource fetcher instead evaluated `json.response || json`, treating `{ "response": null }` as a resource. A foreground reload then erased the client ID and selected session, including a pending task accepted by a newer request. Two embedded cases, both native engines, and a source client test reproduced the failure.

`BaseResource._baseGet` now distinguishes an explicit `response` property from an unwrapped resource. Null reaches the resource's existing null-handling path; ordinary wrapped and unwrapped resources still hydrate normally. The source test verifies all four shapes: null payload, null response, wrapped client, and unwrapped client. Existing session-state tests continue to verify that an authoritative client with removed sessions clears selection.

This response shape is grounded in backend source, not invented as a native-only protocol: `clerk_go@33e0f8279c9b4e3d90d6e4788c67237bc6378a56`, `api/fapi/v1/clients/service.go` (`Read`) and `http.go` (`HTTP.Read`), allow no client response and wrap it when database maintenance prevents creating a replacement. That source inspection does not establish live outage behavior.

## Assertion map

| Baseline declaration | Current disposition |
| --- | --- |
| `testGetResponse` | Embedded startup and foreground recovery issue GET `/v1/client`. The new empty-response tests check the method and preserve the public `clientId` and selected session. The private native service is removed. |
| `getResponseIncludesRequestSequence` | Private response sequence fields are removed. Shared transport assigns request sequences and checks their effects through the response-ordering tests; no public integer counter is introduced. |
| `refreshClientUsesClientServiceGet` | Native service injection and manual `refreshClient` are removed. Packaged startup and lifecycle recovery hydrate generated client/session state through TypeScript. |
| `refreshClientPreservesClientWhenCanonicalResponseRequestsPreserve` | The new embedded and native empty-response checks preserve client ID, session identity/status and credential after a completed foreground refresh. |
| `refreshClientPreservesAdoptedAtomicIdentityWhenCanonicalResponseRequestsPreserve` | The whole-client/date disk snapshot and external identity adoption API are removed. Current empty-response checks preserve the live identity and credential; startup credential migration is covered by the storage audit. No equivalent shared snapshot format is claimed. |
| `refreshClientIgnoresStaleClientResponseSequence` | Existing shared and native response-ordering tests preserve newer session/task/credential state. A rejected generated call throws `stale_client_response` instead of the removed helper returning the current client. |
| `refreshClientIgnoresStaleNilResponseSequence` | The overlapping empty-response case holds a foreground request, accepts a newer pending-task response, then completes the empty request without erasing that task. An empty response is not a client-removal instruction. |
| `updateDeviceTokenStoresTokenAndRefreshesWithoutClientId` | Arbitrary native device-token replacement and private `skipClientId` are removed. Native cached client/date/environment objects are also removed. Startup import and server-issued rotation use the shared credential transport; this is not an equivalent arbitrary-token API. |
| `updateDeviceTokenContinuesWhenInternalStateObserverThrows` | The arbitrary-token API and throwing native internal-state observer are removed. Generated state publication has no such callback contract. |
| `updateDeviceTokenNeverPublishesNewTokenWithPreviousClient` | Arbitrary token injection and its intermediate cleared-client event are removed. The identity audit verifies persistence-before-hydration, coherent token-only updates and rejection of responses issued with an obsolete credential. No old event sequence is promised. |
| `refreshClientIgnoresResponseWhenDeviceTokenGenerationChangesDuringRequest` | Shared credential-rotation tests, including both packaged engines, reject the obsolete request before hydration and preserve newer state. Native mutable generation counters are removed. |
| `updateDeviceTokenRejectsBlankToken` | No arbitrary-token setter is exposed. Its `DeviceTokenError.emptyToken` API is removed; configuration and stored-credential validation are separate contracts. |

## Packaged evidence

Core revision `acfc5359dab0eca6a46ceed3282f2057bc0321f2`, bundle SHA-256 `3c4ea6180da6abd15f6112ce669a8f51a4f48fb389acc2f45331e411323a7bf4`, contract `d0e44f4d5307614738d237be8326540031290579f49e2b098be85596ced06d98`.

All 329 embedded tests and 157 focused source resource tests pass. Full Apple contract suites pass 81 macOS and 78 iOS Simulator declarations, including both empty-response cases and all seven token snapshot cases. All 69 Android fixture cases pass; the opt-in live-startup case reports an unmet assumption and the benchmark is excluded. The Android runner's XML labels that assumption as a failure although Gradle succeeds, so it is not counted as a passing live test. Native tests use headerless empty responses to preserve their existing fixture credential. Reproducible builds, runtime TypeScript checking, binding generation and attached-transport checks pass; generated public API snapshots are unchanged.

This retires these two client files, not the retained general core, middleware, shared-session, or live integration suites. Actual signed-in upgrades, device prompts, live HTTP and physical performance remain release gates.
