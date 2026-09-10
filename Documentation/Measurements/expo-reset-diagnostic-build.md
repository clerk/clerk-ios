# Prepared Expo native-call diagnostic — September 10, 2026

The current Expo proof app compiles as an arm64 iOS Simulator Release app using
JavaScript revision `0b97ed0a260429dda4f230e32bb7e94fde3097f4` and local iOS
worktree revision `c3c5a1fd4f40a2d57d0f8be5c49190b0662ec0f1`. The diagnostic is
installed in the simulator. It has not been launched for measurement: desktop
UI access still reports a locked Mac.

## Workload and implementation

The fixture adds a removable Swift diagnostic to the installed Expo module,
without editing SDK sources. It obtains the existing `ClerkNativeBridge` owner
and connection and never calls `Clerk.connect`. It records CADisplayLink frame
gaps and process footprint/RSS snapshots alongside the operations. A watchdog
cancels the workload after 60 seconds, and completion cancels the watchdog.
The result dictionary contains `Sendable` values for Expo's Promise boundary.

The first build found stale CocoaPods references to a removed local tarball path.
Running `pod install --no-repo-update` regenerated the current package paths,
retaining the local Clerk SPM dependency. A subsequent compile failure at
`Promise.resolve` was fixed in the diagnostic by replacing non-Sendable report
values; SDK concurrency settings were not weakened. The corrected Release build
passed. Metro's empty-cache notice, Hermes undeclared-global warnings and
dependency script-phase warnings remain in the local build log.

Both diagnostics require synthetic session `sess_native` and user `user_native`,
perform 10 warmups and measure 300 generated native `signIn.reset()` calls.
Every measured call requires invalidation of its old email-code group,
advancing native revision, the same native owner/connection and unchanged
session/user wrappers. The JavaScript wrapper rejects any fixture HTTP or
JavaScript-owner change. Individual timers include native-to-Hermes transport,
dispatch, native state application and continuation resumption; the outer
JavaScript diagnostic invocation is excluded from per-operation samples.

## Build identity and reproduction

The [receipt](expo-reset-diagnostic-build.json) records native, Hermes and source
hashes. Linked diagnostic source snapshots make the measured boundaries
reviewable. The actual packaged native manifest and core bytes match the current
core. `hermesc -b -dump-bytecode` recognizes the packaged JavaScript as executable
Hermes bytecode; the current contract and diagnostic call are present. Native
code contains the measurement method and authenticated/collection report keys.
This identifies the compiled diagnostic, not a runtime outcome.

Executable SHA-256: `8d9e656d0d47e71665874c00b81d6fad3f494ecad51746867eed814f83ecc1eb`.
Hermes SHA-256: `e066f83aa67e299d81d31f41b8fbd016fb91a3ed66ff6604c7ad48aefc964557` (3,300,824 bytes).

The local fixture is `work/expo-native-proof/`. Its `measurement/README.md`
describes patching, building, inspecting, installing and executing the diagnostic.
Run only after normal desktop unlocking: open the proof app, wait for its shared
native owner, tap **Measure 300 native resets**, and retain the complete
`[CLERK_EXPO_NATIVE_MEASUREMENT]` report with this artifact receipt. No measurement
samples are supplied in this build report. No phone was used for these builds
or installations.

## Limits

No startup, latency, memory or responsiveness result is claimed. Frame/timer gaps
are diagnostics rather than trace attribution. Before/after process snapshots
are neither incremental owner memory nor continuously sampled startup peaks;
the iOS kernel high-water mark can precede the workload. Same-owner assertions
are not engine-creation counts. Physical-device performance, real service and
platform prompts, shared-owner lifecycle coverage and released-app credential
continuity remain separate acceptance gates.
