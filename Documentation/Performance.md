# Native core release performance budgets

These provisional engineering budgets were selected after the prototype and source/API inventory, on 2026-09-09. They apply to the new native major and the Expo resource projection. They are release gates, not claims that all targets have passed. Change a budget through a reviewed rationale and new measurements; do not raise it automatically to make a failing run pass.

| Metric | Release budget | Measurement |
| --- | --- | --- |
| Fresh core ready, iOS | p95 <= 150 ms | Read and verify bundled code, create engine, load the core and publish the initial authenticated resource graph; deterministic in-memory HTTP/storage |
| Fresh core ready, Android | p95 <= 250 ms | Same boundary as iOS, with the release QuickJS library |
| Generated local operation, both platforms and Expo | p95 <= 10 ms; p99 <= 16 ms | Await `signIn.reset()`, including native state application and invalidation; assert that no HTTP occurred |
| Additional steady process memory | <= 32 MiB | Matched app baseline versus one connected owner, after warm-up and a quiet interval; report managed/native components and collection behavior |
| Additional startup peak memory | <= 64 MiB | Continuously sample one fresh connection versus the same app baseline; report platform footprint/PSS and RSS separately |
| Compressed core bundle | <= 384 KiB | Deterministic gzip level 9 of the exact shipped JavaScript; includes its polyfills |
| Incremental compressed application download | <= 5 MiB per platform/ABI | Matched release application exports with and without the native core; include engine, generated bindings, resources and required dependencies |
| Incremental installed application size | <= 8 MiB per platform/ABI | The same matched exports after installation; exclude debug symbols and test runners |

UI assets and existing application dependencies must be identified separately; do not count a shared dependency twice or omit a new transitive dependency. A multi-ABI AAR is not an installed single-ABI application size. The bundle gzip measurement is a reproducible diagnostic, not an App Store or Play download estimate.

## Procedure and acceptance

Run on physical devices representative of the slowest supported performance tier, in release mode without a debugger. Record model, OS, power/thermal state, architecture, native commit, TypeScript revision, bundle hash and compiler settings. Use at least 30 fresh-process starts, report first/cold and warm-process results separately, and measure at least 300 local operations per device. Repeat an anomalous run only after recording its cause; retain raw samples.

Measure SDK work separately from real network and platform prompt time. Also record real-service time to usable authentication UI; that end-to-end result has no fixed network budget here. The fixture benchmark cannot establish real-service latency or secure-storage performance.

For memory, measure a single owner's startup peak and steady state separately from a repeated connect/close stress run. The stress run must return to a stable retained-memory baseline after owners are released and the runtime has collected eligible objects. Report raw pre-collection peaks too. Forced collection, if used diagnostically, must be labeled and must not conceal normal-process peaks. A sampled value after `connect` is not a measured startup peak.

Run the equivalent Expo local-operation and shared-owner lifecycle workload through Hermes. A native embedded-engine measurement cannot establish Expo's overhead. Verify UI responsiveness during startup and mutations; passing aggregate elapsed-time budgets does not excuse long main-thread stalls.

## Prototype evidence and outstanding gates

On the development machine, the macOS release JavaScriptCore fixture measured startup p95 73.8 ms and local reset p95 4.5 ms (12 fresh engines, 300 calls). This is not an iOS device measurement. Android API 36 on an arm64 emulator with the release library measured 53.9 ms and 3.4 ms respectively (12 engines, 300 calls). Both used deterministic fixture HTTP and signed-out client fixtures; these prototype numbers do not establish the authenticated-startup budget.

The 2026-09-09 bundle at TypeScript revision `5e2b30ccdecf9bc031bcf5506f7faedc0a358c92` is 1,303,468 bytes, or 232,042 bytes with deterministic gzip level 9. Its SHA-256 is `cf934e89ced74e9ff581475f03591b9eb063a2292ec0594733141c43f0ef71cf`.

Android's repeated release-engine run accumulated managed garbage before collection: process PSS rose from 14,202 KiB to 210,843 KiB and returned to 33,010 KiB after close. This is a stress-run sample, not a passing single-owner startup-peak or isolated-engine-memory result. The macOS process peak RSS likewise includes the harness and system libraries.

The later [iPhone Air authenticated-startup measurement](Measurements/ios-iphone-air-authenticated-latency.md) completes 30 fresh physical processes and 300 local operations on that device. It meets the provisional latency limits for that configuration. The [matched physical memory report](Measurements/ios-iphone-air-memory.md) adds three baseline/embedded pairs: 12.344–15.375 MiB incremental steady footprint and 16.094–16.266 MiB incremental kernel startup peaks, with normal owner release and residual memory retained in the evidence. Slower-tier/platform coverage, separate heap attribution, repeated connect/close stability, Expo overhead and UI responsiveness remain open; do not infer full release approval from one device or the bundle-size results.

The later [Simulator lifecycle check](Measurements/ios-simulator-lifecycle.md) verifies twelve authenticated connect/close cycles and 600 resets, with each native owner and runtime released without forced collection. It does not establish a physical retained-memory plateau or separate heap attribution.

## Matched iOS arm64 application exports

The [2026-09-09 iPhone Air export comparison](Measurements/ios-arm64-release-footprint.md) measures a matched API-only SwiftUI harness with and without ClerkKit. Xcode's local app-thinning report estimates an incremental 1,651,319 compressed bytes (1.57 MiB) and 5,364,077 uncompressed bytes (5.12 MiB), within the respective budgets for this development export. This is not observed App Store traffic or a physical filesystem-allocation measurement. Native UI, other target variants, device latency and memory release gates remain separate.
