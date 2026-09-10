# Simulator repeated lifecycle check — September 10, 2026

The Release Embedded fixture completed twelve sequential authenticated
connect/close cycles and 600 generated resets in one iOS Simulator 26.5
(23F77) process. Each cycle verifies stale nested-group invalidation, unchanged
session/user identity and no additional fixture HTTP during its 50 resets.
After close, weak references to both `Clerk` and `CoreRuntime` became nil in all
twelve cycles. No forced garbage collection or allocator purge was requested.

The [report](ios-simulator-lifecycle.json) records every lifecycle assertion,
phase span, source and executable hashes. Its linked compressed raw file retains
all 10,627 memory samples; the largest sampling gap was 10.008 ms. Decompression
reproduces the report's raw SHA-256. All steady and closed windows exceeded the
collector's 400 ms minimum. The native source revision was
`24c57438e136aa0f0ad0dc0184a540ee02c55a29`; the core revision and bundle hash match
the physical single-owner report.

## Reproduction

Build the same `Examples/CoreFootprint` Embedded scheme with Release,
`-destination 'generic/platform=iOS Simulator'`, and `CODE_SIGNING_ALLOWED=NO`.
Install that app on an available simulator, then run:

```sh
xcrun simctl launch --console --terminate-running-process "$SIMULATOR_ID" \
  com.clerk.nativecore.footprint.embedded --memory-stress --exit-after-ready
xcrun simctl get_app_container "$SIMULATOR_ID" \
  com.clerk.nativecore.footprint.embedded data
```

The app prints `CLERK_CORE_MEMORY_STRESS_WRITTEN` and
`CLERK_CORE_FOOTPRINT_READY`, then exits successfully. Copy
`Documents/core-memory-stress.json` from the returned test-app container before
another run overwrites it. Use the phase timing and workload described in
`Examples/CoreFootprint/README.md`.

## Limits and physical attempt

This verifies bounded native-owner/runtime release with the actual bundled
JavaScriptCore execution. Weak-reference release does not prove that all engine
pages were returned to the OS. There is no matched Simulator baseline in this
run, no native/JavaScript heap attribution, and no physical performance or
retained-memory plateau acceptance claim. The memory values remain in the raw
report for diagnosis; they are not substituted for physical device measurements.

An earlier physical repeated-lifecycle attempt retained a completed baseline,
but its embedded launch timed out. That incomplete attempt supplies no paired
result. The user then requested use of their phone and directed subsequent work
to the simulator. The collector ended and the remaining dedicated app process
received a termination signal. Local failed-run logs and partial baseline data
remain in `work/ios-physical-memory-stress-raw/`; they were not retried or folded
into a successful physical result. Physical phone work remains deferred until
the user makes it available again.
