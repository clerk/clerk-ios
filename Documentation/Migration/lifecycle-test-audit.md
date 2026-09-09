# Lifecycle assertion migration

Baseline: `02f98f89a19b6c079517c9aae07df7edd0e600e5`. This audit reads every assertion in `Tests/Lifecycle/LifecycleManagerTests.swift` (5 tests), `TaskCoordinatorTests.swift` (6), and `SessionPollingManagerTests.swift` (24). Token fetcher/freshness and identity tests are separate audits.

## Retained observable behavior

`NativeCoreContractTests/PackagedCoreTests.swift` now tests lifecycle behavior against the real packaged JavaScriptCore bundle and generated resource objects, with fixture HTTP responses:

- Post the platform's inactive/active notifications through `NotificationCenter`. Inactive state does not start a client refresh; activation refreshes the generated available-session list. Another active notification does not repeat that refresh.
- Available sessions do not automatically become the active session. The tests preserve the core's explicit activation/finalization contract.
- A failed foreground reload produces `lastLifecycleError` while the runtime remains available. A generated reset still succeeds, and a later inactive/active transition can refresh sessions successfully.
- Closing the connection removes its observers. Later notifications cause no further client reads.
- Releasing the last Clerk owner deallocates its runtime and stops lifecycle observation without requiring an explicit close.

The platform notifications are posted by the test; this proves notification wiring, core execution and resource observation, not real OS suspension, process death, live authentication or a signed-in app upgrade. The packaged-core suite is serialized because these notifications are process-wide.

`Session.test.ts` and `tokenCache.test.ts` in the JavaScript repository pass 166 tests. Relevant retained cases include suppressing proactive requests while the native app is inactive and allowing foreground token recovery, retaining cached tokens during pending refresh, continuing after refresh failure, replacing tokens after refresh success, and avoiding a stale headless timer refresh after expiry. These exercise the TypeScript owner; they do not promise the old Swift poller's numerical schedule.

## Validation

The dedicated scheme passes 46 tests on macOS and 43 on iOS Simulator, including
the three new lifecycle checks. System contacts/LinkServices diagnostics remain
visible in the macOS log; they do not fail tests. The TypeScript run reports
existing Vite configuration/plugin deprecations.

## Exact old test dispositions

| Old assertions | Disposition |
| --- | --- |
| Lifecycle `startsObserving`, `testStopObserving`, repeated start/stop, and `deinitStopsObserving` | These five tests only call the old manager; none assert receipt of an event or cleanup. Replace them with the actual notification/resource/teardown checks above. The private start/stop manager API is removed. |
| Task `tracksTask`, `createsAndTracksTask`, `tracksMultipleTasks`, `taskWithCustomPriority` | These assert execution/completion of generic Swift tasks through the removed private `TaskCoordinator`. There is no new public task-factory or priority API. The runtime and host adapters use structured tasks. |
| Task `cancelAllTasks`, `deinitCancelsAllTasks` | The old assertions permit either cancellation or non-completion. Preserve actual cancellation at the host boundary: browser/credential/HTTP contract suites verify cancelled requests, and packaged lifecycle tests verify owner teardown. The old generic coordinator is not retained. |
| Polling repeated start/stop | Removed private timer/poller API. There is one core owner; duplicate active notifications and closed/deallocated owners are checked through the packaged core. |
| `shouldRefresh` for nil, pending and active session | Removed native decision helper. The core owns session/token eligibility. Foreground resource refresh includes available sessions and leaves adoption explicit; a second Swift eligibility policy is not introduced. |
| Token refreshed resets backoff; newly active session resets it; same active session does not; pending-to-active resets it; activation while polling resets it; stopped poller leaves it unchanged | These seven tests inspect the deleted Swift poller's `consecutiveFailures`. The TypeScript cache/session tests cover successful refresh, failure, cached-token availability and native background suppression. Exact Swift counter values are intentionally retired. |
| Restart polling receives auth events; refresh with a non-refreshable session resets backoff | Removed private event subscriber and counter. Native lifecycle recovery now invokes the existing core resource reload. No second native auth-event subscriber is retained. |
| Initial counter zero; failure increments; success resets | Removed Swift backoff state. These are internal algorithm assertions, not a public behavior contract. |
| Base interval; doubling; maximum cap; +/-20% jitter; reset to base; 60-second default; custom maximum; full expected progression | Removed Swift retry/timer policy. The TypeScript implementation remains the owner; old numeric defaults and jitter are not reproduced in Swift. |

After passing the replacement checks, the three reviewed lifecycle test files can be retired with their deleted implementations. This does not authorize retirement of the separate session-token or identity suites, and does not claim those release gates are complete.
