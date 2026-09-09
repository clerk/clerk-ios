# Owner replacement assertion audit

Reviewed all 24 test declarations and their assertions in the baseline
`Tests/Core/ClerkReconfigureTests.swift`. The mutable global `Clerk.reconfigure`
operation is removed. A connected owner has immutable configuration. Validate
the new `ClerkConfiguration`, close the old owner, and connect the replacement.

`close()` does not sign out, erase credentials, or clear another instance's
storage. Reconnecting to the same instance can restore its saved credential.
Use the generated sign-out operation when sign-out is intended. A failed new
connection does not automatically reopen an owner already closed by the app.
The old transactional reconfiguration and rollback contract is not retained.

| Baseline test | Disposition |
| --- | --- |
| `reconfigureUpdatesConfiguration` | Same global object, mutable options, proxy and native instance-type fields are removed. Configuration tests cover the normalized key and derived HTTPS origin. |
| `reconfigureUpdatesInstanceTypeForLiveKey` | The live-key configuration case covers the input and origin. Instance mode is core-owned. |
| `invalidReconfigureLeavesCurrentInstanceUntouched` | `replacingAnOwnerInvalidatesOldResourcesAndPreservesItsCredential` validates a bad replacement configuration while the original signed-in fixture owner remains available with the identical session wrapper. There is no global dependency-container replacement. |
| `reconfigureWaitsForActiveKeychainClear` | The global keychain-clear task and reconfiguration lock are removed. This old wait-order assertion is not a replacement-core guarantee. |
| `reconfigureClearsLocalStateAndStorage` | Destructive clearing of source and target stores, native session indexes and native token cache is removed. Closing invalidates the old resources and preserves credentials, covered by the owner-replacement test. Storage namespace isolation has separate Keychain tests. |
| `reconfigureWithSameKeychainClearsStorage` | Intentionally changed: owner replacement preserves the credential in the same namespace. The packaged test reconnects with that credential and obtains a usable new session wrapper. |
| `samePublishableKeyReconfigureClearsAdoptedSharedIdentity` | Destructive reconfiguration and live shared-session replication are unavailable. Migration import and interrupted-clear handling have separate storage proofs; they do not provide live convergence. |
| `missingSharedEntitlementPreflightRunsBeforeDestructiveWrites` | No destructive reconfiguration preflight exists. Storage tests cover entitlement errors without a fallback read; signed-in shared-entitlement upgrades remain a release gate. |
| `failedReconfigureLeavesPreviousRuntimeUntouched` | No transactional storage deletion or automatic rollback exists. Validate configuration before closing; a subsequent connection failure is surfaced to the app. |
| `failedRecoveryPreflightLeavesPreviousRuntimeInstalled` | Old runtime installation and shared-slot recovery rollback are removed. Credential migration independently rejects malformed or unavailable clear-recovery records. |
| `keychainClearStartedDuringReconfigurationWaitsForInstalledRuntime` | The global reconfiguration barrier and static keychain-clear entry point are removed. |
| `failedDestructiveReconfigureRetainsPreviousOwnerSlot` | Destructive owner-slot clearing and its rollback are unavailable. This is not claimed as passing current coverage. |
| `reconfigureDrainsPendingCacheWritesBeforeClearingOldKeychain` | Native resource-cache writes are removed. Shared credential transport owns persistence fencing; owner replacement does not clear the old namespace. |
| `reconfigureClearsTokensBeforeSessionChangedEvent` | The native global token cache and `auth.events` stream are removed. Current token state belongs to one JS owner; a closed session cannot make token requests. |
| `tokenReadsAreCancelledWhileReconfigureIsInProgress` | There is no in-place reconfiguration window. A closed session throws `stale_resource` without HTTP, and a replacement session can get a token; both are checked through generated methods. |
| `tokenReadBeforeConfigureThrowsConfigurationError` | Standalone mock sessions and global configuration are removed. Generated sessions are acquired from a connected owner; no equivalent unconfigured session can be constructed through the public API. |
| `reconfigureBeforeConfigureInstallsSharedInstance` | Initial connection returns an application-owned instance; no shared singleton is installed. Packaged-core tests execute this connection. |
| `reconfigureBeforeConfigureClearsPersistedCredentials` | Intentionally changed: connecting may restore credentials and does not erase them preemptively. |
| `concurrentReconfigureThrowsWhileFirstReconfigureIsInProgress` | The global lock and its error are removed. Apps must serialize their owner replacement and avoid creating competing owners for one credential namespace. |
| `oldInFlightClientResponseIsIgnoredAfterReconfigure` | Old native service requests are removed. `CoreTerminalStateTests` proves delayed bridge delivery cannot publish revisions or lifecycle errors after closure or fatal failure. It does not claim to reproduce the old service mock's HTTP cancellation race. |
| `staleRefreshClientDoesNotApplyAfterReconfigure` | The old refresh service is removed. Closed resources reject calls; delayed native state delivery is ignored. Shared runtime tests separately cover in-flight authentication/credential fencing. |
| `staleRefreshEnvironmentDoesNotApplyAfterReconfigure` | Same terminal-state boundary applies to all resource projections; no native per-domain refresh checkpoint remains. |
| `reconfigurePreservesRegisteredAuthFlow` | The old global auth-flow registration/snapshot/reset API is removed. Presentation owns its new connected owner and reacquires resources; registrations are not transferred automatically. |
| `authEventsStreamRemainsUsableAfterReconfigure` | No global stream survives replacement. Swift observation follows the new owner supplied by the app. |

The terminal-state tests reproduced a Swift defect: callbacks retained before
transport closure still changed the runtime revision, epoch and lifecycle error
after close or fatal failure. `CoreRuntime.receive` now ignores unavailable
owners, matching the Android runtime's existing behavior. The replacement test
uses the packaged JavaScriptCore implementation with fixture HTTP/storage. It
does not prove a released-app upgrade, live session restoration, or physical
device behavior. These reviewed assertions do not cover the separate remaining
`ClerkTests` or `ClerkResponseClientStateTests` files.
