# iOS arm64 release footprint — 2026-09-09

Matched SwiftUI apps use the same source and packaged fixture. Only the embedded variant links the local ClerkKit package. The harness is in `Examples/CoreFootprint`; these measurements use production native source at `5b678843a61e1a0df827222f1aee0c0bcbacad95`, with the harness added in the commit containing this report. Xcode 26.5 (17F42), iOS 26.5 SDK, minimum iOS 17, arm64, Swift `-O` whole-module compilation and dead stripping were used. Both apps were development-signed using an existing local profile, archived, and exported locally. No account updates or uploads were requested.

## Xcode app-thinning estimates

The local `debugging` exports requested `thinning=iPhone18,4` (iPhone Air), with Swift symbol stripping. Both exports produced one variant containing the requested descriptor. Numbers come from Xcode's `app-thinning.plist`, not rounded text or generic ZIP compression.

| Bytes | Baseline | Embedded core | Difference |
| --- | ---: | ---: | ---: |
| Compressed app estimate | 27,516 | 1,678,835 | 1,651,319 |
| Uncompressed app estimate | 129,620 | 5,493,697 | 5,364,077 |

The compressed difference is **1.57 MiB**, below the 5 MiB budget for this export estimate. The uncompressed difference is **5.12 MiB**, below the 8 MiB budget as an estimate. Apple describes the app-thinning report's compressed and uncompressed sizes as download and installed sizes respectively; these remain local development-export estimates, without an observed App Store transfer or device filesystem-allocation measurement. [Apple's size measurement documentation](https://developer.apple.com/documentation/Xcode/reducing-your-app-s-size).

[Raw export report](ios-iphone-air-export-size.json) records exact IPA hashes, the Xcode report hashes, matching model/OS descriptors, shared fixture hash and shipped core identity. No personal profile, certificate or device identifiers are included.

## Build versus archive diagnostics

| Logical file bytes | Baseline | Embedded core | Difference |
| --- | ---: | ---: | ---: |
| Ordinary release build | 144,547 | 8,727,296 | 8,582,749 |
| Release archive after stripping | 124,419 | 5,488,496 | 5,364,077 |

Archive stripping matters: comparing ordinary build products would overstate the executable contribution. The archive's executable difference is 3,948,960 bytes. The shared fixture is present in both apps. System JavaScriptCore is supplied by iOS; no engine framework is copied into the app. Development signatures, profiles, core notices and privacy resources are included. The app-size script verifies signatures, arm64, absence of embedded DWARF sections and exact core SHA. [Build files](ios-arm64-release-app-size.json) and [archive files](ios-arm64-release-archive-size.json) retain per-file hashes and diagnostic ZIP sizes.

The embedded JavaScript is 1,314,690 bytes, or 234,247 bytes with deterministic gzip level 9. Its SHA-256 is `85fd61ac8a7d5ca95c5be7c8bbfa17d2004eb13c280f587ebc8d24d50f9aa52c`, pinned to TypeScript revision `617418e19cd985de98333a5df3c8ab3b2d360190`. The core gzip passes the 384 KiB bundle budget.

## Scope and validation

Both signed ordinary-build apps installed on the paired iPhone Air running iOS 26.6.1. The initial launches were blocked by iOS device locking, so installation alone establishes no physical runtime or latency result. The separate benchmark runner is prepared for 30 fresh processes and 300 generated resets; no physical latency data is included in this size report. The release embedded app did execute successfully on the iOS 26.5 simulator: it created the real JavaScriptCore owner, emitted ten reset samples with unchanged HTTP request count, reported readiness and exited successfully. The baseline release simulator app also reported readiness and exited successfully. This [raw harness check](ios-footprint-harness-validation.json) establishes functional behavior, not physical-device performance.

The default platform factory remains linked through explicit manual live mode. ClerkKitUI and explicitly constructed authentication presenters are outside this API-only harness. No real account, platform prompt, signed-in upgrade, UI responsiveness, memory peak or lowest-tier performance claim follows from these sizes. Other Apple platforms and device variants require their own checks.

Reproduce builds and measurements with the [harness instructions](../../Examples/CoreFootprint/README.md). Archive each scheme with `xcodebuild archive`, then use `xcodebuild -exportArchive` with local debugging export, model-specific thinning and Swift symbol stripping. Read the resulting exports with `scripts/measure-native-core-export.py`.

Tooling corrections retained for reproducibility: manual selection of an Xcode-managed wildcard profile was rejected, and globally passing an app profile also affected the SPM resource bundle; automatic signing reused the existing profile successfully without provisioning updates. Sandboxed signature verification reported `CSSMERR_TP_NOT_TRUSTED`; verification passed with access to the existing local trust store. A separate simulator DerivedData directory attempted uncached package clones and failed DNS resolution; the functional check reused the existing package cache. Xcode's only remaining build warning was skipped AppIntents metadata extraction because these apps do not use AppIntents.
