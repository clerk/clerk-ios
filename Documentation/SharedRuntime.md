# Shared Clerk runtime

ClerkKit adapts the public Swift API to one Clerk.js resource tree. The generated invocation types and snapshots are shared with the JavaScript SDK; resource resolution, API payloads, session token caching, authentication completion, and structured errors belong to JavaScript.

## Runtime ownership

| Host | Clerk.js owner | Native responsibilities |
| --- | --- | --- |
| Swift application | One embedded JavaScriptCore host per configured Clerk runtime | HTTP transport, Keychain, OS ceremonies, lifecycle signals, observable projections |
| Expo on iOS | The existing Clerk.js instance in Hermes | Native UI projections, Keychain and OS ceremonies, operation forwarding |
| Watch companion | The paired iPhone's configured runtime | Versioned state replication, synchronous authorization projection, paired-phone operation transport |

State publications carry a protocol version, runtime generation, and increasing revision. ClerkKit commits identity and credentials through its identity controller before exposing the state or emitting a token refresh event. A discarded runtime cannot publish into a replacement configuration. Swift does not interpret HTTP response bodies as a second mutable Clerk resource tree.

Custom `Clerk.Options.middleware` hooks wrap the embedded host HTTP transport. Request hooks receive the final JavaScript request; response hooks validate the bytes before JavaScript processes them. Disposing the runtime cancels transport and suspended middleware work. JavaScript owns retry policy and resource updates. In Expo, the existing JavaScript owner supplies transport.

## External runtimes

The `ClerkExpo` SPI configures an external engine with an initial snapshot and an asynchronous JSON invocation channel. The factory is installed before native configuration, so initialization cannot create an embedded Clerk client. Native operations carry expected client and session IDs; the JS owner rejects operations from stale native screens before mutation. External snapshots use the same identity commit path as embedded snapshots.

Native callbacks may supply secure storage, random bytes, SHA-256, WebAuthn ceremonies, Apple credentials, biometric credentials, and App Attest. These capabilities do not allocate a Clerk JavaScript runtime. Synchronous authorization uses the separately bundled shared authorization functions and does not instantiate a second Clerk client.

Disposing a connection cancels pending native waits and OS ceremonies. The external JS owner retains its resources, credential cache, and application lifecycle. Reconnecting requires a new runtime ID and authoritative initial state.

## Verification

`EmbeddedPublicLifecycleTests` exercises the production embedded bundle through public Swift APIs with controlled HTTP transport. `ClerkExternalRuntimeTests` covers external configuration, ordered state application, public operation forwarding, and cancellation. `WatchOperationTests` exercises paired-phone invocation and authoritative reply application. Protocol and adapter tests in the JavaScript repository validate the same resource boundary.

The Expo iOS adapter requires a coordinated native SDK release. For local integration, use `CLERK_IOS_SDK_PATH` when installing Expo's pods and rebuild the native app. Android native UI requires a separate external-runtime adapter.
