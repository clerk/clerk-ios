# Packaged-core authentication UI journey

This test app renders the SDK's production `AuthView` with a real `Clerk.connect`
JavaScriptCore owner. Its HTTP and credential-storage capabilities use deterministic
fixtures. It does not authenticate a real account or make live service requests.

Run from the repository:

```sh
make test-auth-journey
```

The runner selects an available iPhone Simulator, preferring a booted device.
Set `IOS_SIMULATOR_DESTINATION='platform=iOS Simulator,id=<UDID>'` to choose one.
`CLERK_AUTH_JOURNEY_OUTPUT` selects a fresh evidence directory;
`CLERK_AUTH_JOURNEY_DERIVED_DATA` selects the reusable build directory. The default
locations are under `.build`. Existing result bundles are never overwritten.

The checked-in app dependency lockfile pins the tested package dependencies. The
runner disables automatic package resolution. It runs the actual UI test, requires
the exact passing case, and exports the three named screenshots and XCTest reports.
Shared CI invokes the same command after the existing ClerkKitUI tests and retains
its evidence directory, including the result bundle when the test fails.

The test enters an email address, checks an invalid-code error without activation,
closes the native error sheet, and types the replacement code. Production prebuilt
UI performs finalization. The app reveals authenticated content only when
`clerk.isAuthFlowComplete` becomes true. A test-app footer exposes the real session
and user plus fixture request/callback counts for assertions. Those diagnostics
and all fixture code belong to this app, not the distributed SDK.

See the [recorded journey and limitations](../../Documentation/Migration/rendered-auth-journey.md).
