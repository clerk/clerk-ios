# Foreground recovery and browser authentication

Returning from an authentication browser can foreground the application before callback redemption completes. The previous packaged core immediately reloaded the client, rotated its credential, and rejected the still-pending redemption with `stale_client_request`.

The shared TypeScript owner now defers automatic lifecycle/connectivity recovery while generated resource invocations remain in flight. It coalesces those recovery requests and runs them when the owner is idle, active, online, and not disposed. Cancellation can resolve a caller before the underlying work settles, so caller cancellation alone does not release the deferral. Failed operations do release it. Native code continues to report lifecycle events; it does not implement an authentication polling loop or enumerate pending authentication services.

Resource calls remain concurrent. This correction does not disable response freshness fences or serialize new resource calls against a reload that already started. A long-running resource call postpones newly requested recovery until its actual work settles. An attached Expo core retains its existing owner's lifecycle policy.

## Verification

- The shared protocol regression failed before the fix with `stale_client_request`. All six new scenarios now pass, covering OAuth redemption and deferred recovery after failure, cancellation, backgrounding, going offline, and disposal. The complete embedded suite passes 549 tests; TypeScript checking and bundle reproducibility pass.
- Android `LifecycleContractTest.foregroundDuringOAuthRedemptionWaitsForAuthentication` failed on the previous packaged QuickJS bundle: the foreground event started a second client read and callback redemption failed. All five lifecycle tests and the separately selected 11-test `PackagedCoreTest` suite pass with the new bundle on the Android 16 emulator. A combined class filter discovered only the lifecycle suite; the separate run is the packaged-suite evidence.
- Apple `PackagedCoreTests.foregroundDuringOAuthRedemptionWaitsForAuthentication` failed on the previous packaged JavaScriptCore bundle with the same second-read and stale-credential failures. The updated 42-test packaged suite passes on macOS and the iOS Simulator.

The tests suspend fixture HTTP during a generated SSO call and send native lifecycle events before releasing callback redemption. They verify complete sign-in state, explicit session adoption, and a single queued refresh using a rotated credential. They do not perform a live provider login or interact with a real browser/Custom Tab. The initial Apple per-method filter discovered zero tests; that run is excluded from the proof. The containing suite was run to establish both failure and success.
