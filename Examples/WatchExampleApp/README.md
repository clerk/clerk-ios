# WatchExampleApp on the generated core prerelease

The iPhone app uses one retained generated Clerk owner and native authentication
UI. Supply `CLERK_PUBLISHABLE_KEY` through the scheme environment or the existing
ignored `LocalSecrets.plist` mechanism. Its registered callback is
`com.clerk.WatchExampleApp://oauth/callback`.

The watchOS app compiles against the generated resource API, but standalone
`Clerk.connect` currently fails with `capability_unavailable:embedded_engine`:
JavaScriptCore is not available to this watchOS target. The example presents an
explicit unavailable state. It does not claim sign-in or token access works.

The old `watchConnectivityEnabled` option and phone/watch identity synchronization
are not implemented in this prerelease. Installing both applications or enabling a
Watch Connectivity entitlement does not restore that behavior. Existing applications
that require it must remain on the previous major until a supported runtime and
synchronization design is implemented and verified.

Build the `WatchExampleApp` and `WatchExampleApp Watch App` schemes from
`Clerk.xcworkspace`. Simulator compilation verifies API/platform availability only;
it does not establish signed-in watch behavior or real device upgrade continuity.
