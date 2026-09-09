# Apple platform validation for the generated-core prerelease

The package declares iOS 17, Mac Catalyst 17, macOS 14, watchOS 10, tvOS 17, and
visionOS 1. Declarations and successful compilation do not imply that every
authentication capability has been validated on a device.

The following checks used the installed Xcode 26.5 SDKs on 2026-09-09.

| Target | Core / UI compilation | Execution and limitations |
| --- | --- | --- |
| iOS | ClerkKit, ClerkKitUI, Quickstart, CustomFlows, Airbnb, E2EHost, and watch companion compile for the simulator. | Packaged-core and SwiftUI fixture tests pass. Real browser/passkey/biometric prompts and released-app upgrades remain gates. |
| macOS | ClerkKit, ClerkKitUI, and MacExampleApp compile. | JavaScriptCore packaged execution, GET-only live service startup, and isolated Keychain process-restart checks pass. Fixture benchmarks are not physical-iPhone release measurements. |
| Mac Catalyst | ClerkKit and ClerkKitUI compile for arm64 and x86_64. | JavaScriptCore is present. Platform sign-in and device-upgrade execution remain unverified; autofill-assisted passkeys are unavailable. |
| visionOS | ClerkKit and ClerkKitUI compile for the simulator. | JavaScriptCore is present. Platform prompts and device execution remain unverified. Registration with excluded credentials currently reports an explicit capability error. |
| watchOS | ClerkKit and the watch example compile for arm64 and x86_64 simulator targets. | The SDK has no JavaScriptCore framework. Standalone `connect` reports `capability_unavailable:embedded_engine`; phone/watch identity synchronization is not implemented. This prerelease does not provide working standalone watch authentication. |
| tvOS | The complete ClerkKit source compiles directly against the installed tvOS simulator SDK for arm64, with the generated package-resource accessor. | JavaScriptCore is present. Xcode cannot select a tvOS destination because its runtime component is missing, so package/UI build and execution are unverified. The supplied browser/passkey/Apple identity presenter is excluded on tvOS; LocalAuthentication is absent from this SDK. |

The tvOS compiler check is a module check, not a packaged application test. It uses
Swift 6, the package name, `SWIFT_PACKAGE`, and the declared tvOS 17 deployment
target. No simulator component was installed as part of this check.

`AppleAuthentication` implements browser, passkey, and Apple identity presentation
on iOS, macOS, Mac Catalyst, and visionOS. Applications retain it and provide their
presentation anchor. HTTPS callbacks require iOS 17.4, macOS 14.4, or visionOS 1.1
and the corresponding verified-link configuration. The core reports unsupported
capabilities explicitly; a generated method is not evidence of OS availability.

See [performance budgets](Performance.md) and [migration gates](Migration/README.md)
before making a release-support claim. In particular, watch synchronization and
live device continuity cannot be inferred from fixture state or a compile result.
