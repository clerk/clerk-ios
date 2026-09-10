# Matched iOS core measurement apps

`Baseline` and `Embedded` use the same SwiftUI source and FAPI fixture. Only `Embedded` links the local `ClerkKit` package. `EMBEDDED_CORE` selects that code explicitly, so a shared compiler module cache cannot accidentally add Clerk to the baseline.

The embedded app creates one JavaScriptCore-backed owner using bundled fixture HTTP and in-memory storage, awaits the generated `signIn.reset()`, and verifies that its old nested email-code group was invalidated. A successful run displays `Ready`. There are no service calls or system authentication prompts in fixture mode. The optional `CLERK_FOOTPRINT_LIVE_KEY` process environment variable selects the normal platform factory for manual live work; benchmark mode rejects this combination. This keeps the default factory reachable by dead stripping, but does not represent the size of ClerkKitUI or all explicitly constructed authentication presenters.

## Build and install

Use Xcode's `Release` configuration and a generic iOS device destination. The app project contains no personal team, certificate, device identifier or provisioning profile. Supply a team whose existing local profile covers the test device. Account updates are not required when that profile already exists.

```sh
xcodebuild -project Examples/CoreFootprint/CoreFootprint.xcodeproj \
  -scheme Embedded -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath /tmp/clerk-footprint CODE_SIGN_STYLE=Automatic \
  DEVELOPMENT_TEAM="$FOOTPRINT_TEAM" CODE_SIGN_IDENTITY='Apple Development' build
# Repeat with -scheme Baseline.
xcrun devicectl device install app --device "$FOOTPRINT_DEVICE" \
  /tmp/clerk-footprint/Build/Products/Release-iphoneos/Embedded.app
# Repeat with Baseline.app. Only these dedicated measurement apps are involved.
```

An Xcode-managed local profile should be selected by automatic signing. Passing its UUID as a global manual profile also applies it to the SPM resource bundle, which cannot carry an app provisioning profile.

## Fresh-process latency

Unlock the physical device and keep its screen awake. The runner launches only `com.clerk.nativecore.footprint.embedded`, without a debugger, and each process exits after reporting. It retains console logs and devicectl JSON separately; only the app's own marked JSON is parsed from console output. Failed launches stop the run, retaining the evidence; there is no automatic retry or sample filtering. Use a new raw directory after resolving a launch failure.

```sh
python3 scripts/measure-native-core-device.py \
  --device "$FOOTPRINT_DEVICE" --model "$FOOTPRINT_MODEL" \
  --native-revision "$(git rev-parse HEAD)" \
  --app-bundle /tmp/clerk-footprint/Build/Products/Release-iphoneos/Embedded.app \
  --raw-directory /tmp/clerk-footprint/latency-raw \
  --output /tmp/clerk-footprint/latency.json
```

There are at least 30 unique processes. Each times one `Clerk.connect` including bundle read/hash verification, engine creation, fixture HTTP and an authenticated session/user projection. Benchmark mode uses the authenticated client fixture with a freshly timed synthetic token; fixture parsing, token construction and configuration creation precede the timer. The app and runner reject a missing authenticated projection. One unmeasured reset warms the local operation path; ten measured generated resets follow, each asserting invalidation, unchanged session/user identity and no additional HTTP. The report retains all 300 operation timings, startup samples, thermal state, low-power mode, OS and source/binary hashes. Percentiles use nearest rank; the median uses the arithmetic middle for an even sample count.

The first sample is separate from later fresh processes. Neither is a guaranteed cold filesystem or reboot measurement. These results do not establish secure-storage/network time, memory peaks, UI responsiveness, or performance on the slowest supported hardware. Consult [the release budgets](../../Documentation/Performance.md).

## Physical single-owner memory

Build and install both release variants from the same committed source. The
memory mode runs only against fixture data and rejects a live key. It creates
one authenticated owner in Embedded and none in Baseline. A private dispatch
queue samples `TASK_VM_INFO` every 5 ms with 1 ms timer leeway; actual gaps are
reported. Sampling begins before fixture preparation and the core connection.
The fixed observation phases include startup, 50 generated resets for warm-up,
three quiet seconds before a one-second steady window, and five quiet seconds
after close before a one-second closed window. The native owner must be released.
No garbage collection or allocator purge is requested.

```sh
python3 scripts/measure-native-core-memory.py \
  --device "$FOOTPRINT_DEVICE" --model "$FOOTPRINT_MODEL" \
  --native-revision "$(git rev-parse HEAD)" \
  --products /tmp/clerk-footprint/Build/Products/Release-iphoneos \
  --raw-directory /tmp/clerk-footprint/memory-raw \
  --output /tmp/clerk-footprint/memory.json
```

The default is three fresh-process pairs, alternating app order. Failed launches
stop collection without retrying or dropping evidence. The collector retrieves
each report from that measurement app's own data container, retains the raw JSON
and a deterministic gzip copy, and reports paired startup maxima, steady medians
and closed medians. Raw sample hashes accompany the summary.

Footprint, resident memory and VM internal/external/compressed fields are separate
measurements, not quantities to sum. VM categories do not identify the Swift and
JavaScript heaps individually. The kernel's process-lifetime footprint peak is
also retained; it can precede the sampled core-startup phase. Sampling and its
retained buffer contribute to both apps. These observations do not establish UI
responsiveness, real-service memory, repeated connect/close stability or coverage
of slower hardware. See [Apple's memory guidance](https://developer.apple.com/documentation/xcode/reducing-your-app-s-memory-use).

## Signed app file sizes

```sh
python3 scripts/measure-native-core-app.py \
  --baseline /tmp/clerk-footprint/Build/Products/Release-iphoneos/Baseline.app \
  --embedded /tmp/clerk-footprint/Build/Products/Release-iphoneos/Embedded.app \
  --native-revision "$(git rev-parse HEAD)" \
  --output /tmp/clerk-footprint/app-size.json
```

The size script verifies code signatures, arm64, absence of embedded DWARF sections, the shared fixture, and the exact core manifest SHA. It records per-file hashes and a deterministic diagnostic ZIP. Signature verification requires access to the local signing trust store. The script accepts archived `.app` paths as well, allowing normal archive stripping to be measured separately from ordinary build products.

Logical file bytes do not equal device filesystem allocation, and ZIP compression does not equal App Store delivery. Development profiles and signatures are included. Do not claim the installed-size or download budget passed from these diagnostics alone.

For Xcode's own download/installed estimates, archive each scheme using `-archivePath` and export each archive with `-exportArchive`. Use an export-options plist containing `method=debugging`, `destination=export`, `signingStyle=automatic`, the existing `teamID`, `thinning=iPhone18,4` (or the target model), and `stripSwiftSymbols=true`. No upload or provisioning-update flag is needed.

```sh
python3 scripts/measure-native-core-export.py \
  --baseline-export /tmp/clerk-footprint/baseline-export \
  --embedded-export /tmp/clerk-footprint/embedded-export \
  --model iPhone18,4 --native-revision "$(git rev-parse HEAD)" \
  --output /tmp/clerk-footprint/export-size.json
```

This reads exact byte values from Xcode's `app-thinning.plist`, verifies a matching model descriptor and identical fixture, and records IPA and core hashes. The report preserves the distinction between a local export estimate and physical-device or App Store observations.
