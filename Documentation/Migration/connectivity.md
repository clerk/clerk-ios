# Connectivity and lifecycle recovery

Standalone connections subscribe to operating-system connectivity after successful initialization. Apple uses `NWPathMonitor`; Android uses the default-network callback from `ConnectivityManager` and declares `ACCESS_NETWORK_STATE`. Closing the owner unregisters the subscription. Apple also unregisters when the last owner is released. Android applications must explicitly close a replaced owner.

The native adapter reports a boolean to the embedded core. Apple permits requests when the path is satisfied. Android permits requests when the default network has Internet and validated capabilities, ignores loss of a replaced default network, and falls back to unknown/eligible if monitoring cannot be registered. These are OS observations, not proof of Clerk reachability; HTTP can still fail.

TypeScript owns recovery. Offline state changes shared network eligibility and defers foreground recovery. A transition back online refreshes resources while active; restoration in the background waits for foreground. Duplicate recovery events share the current reload. If connectivity returns while an older reload is still failing, recovery runs again after it settles. Successful refresh does not implicitly adopt a listed session. Errors remain nonfatal and use `lastLifecycleError`.

Expo's attached transport leaves connectivity and recovery to its existing JavaScript owner. The native facade does not replace that owner's network policy.

## Evidence and limits

Four shared tests execute the real bundled core and cover restoration, duplicate events, background/offline deferral, restoration during a failing request, structured invalid-message failure, and disposal. The full embedded suite passes 146 tests. Native contract tests inject connectivity events at the subscription boundary and assert observable generated resources, explicit session adoption, and subscription cleanup; both packaged engines execute the same bundle.

This closes the previous automatic reconnect gap for an initialized standalone owner. It does not implement offline cold-start initialization, automatic retry of a failed `connect`, process-death recovery, or live shared-session synchronization. Actual device network interruption, signed-in old-major upgrades, and live HTTP recovery remain release validation gates.
