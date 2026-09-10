# Physical authenticated startup — September 10, 2026

The release CoreFootprint fixture completed 30 unique iPhone Air app processes
and 300 generated local resets at 13:21 UTC on September 10. The app ran on
iPhone18,4, iOS 26.6.1 (23G83), without a debugger. All samples reported nominal
thermal state and low-power mode disabled. This is one physical device, not
representative slowest-tier coverage.

| Measurement | Result | Provisional budget |
| --- | ---: | ---: |
| Authenticated startup p95 | 57.194 ms | 150 ms |
| First fresh-process startup | 71.186 ms | Reported separately |
| Startup median | 54.410 ms | No separate median limit |
| Generated reset p95 | 6.033 ms | 10 ms |
| Generated reset p99 | 7.494 ms | 16 ms |
| Maximum reset | 8.578 ms | Reported separately |

The [raw aggregate](ios-iphone-air-authenticated-latency.json) retains all 30
startup samples, all 300 operation samples, process IDs, collection timestamps,
thermal/power state and source/binary hashes. No sample was retried or discarded.
Individual devicectl receipts and console output are retained locally under
`work/ios-physical-authenticated-latency-raw/`; the collection log is
`work/ios-physical-authenticated-latency.log` in the task workspace.

## Boundary and provenance

The measured native revision is `60c6a481df234954de50c064d53463db600a1300`.
It bundles TypeScript revision `0b97ed0a260429dda4f230e32bb7e94fde3097f4`,
SHA-256 `86d665dd87bc188352594cf80a5c0c5927348d84d9de6382e927d4da8abc9cd3`.
The app was compiled in Release mode, Swift `-O` whole-module optimization,
arm64, with development signing. Strict code-signature verification passed.
The committed source was rebuilt after the formatting hook, and that exact
build was installed before collection. Executable SHA-256 is
`7c09e30f5adbd958ce2abe4027f889250da2665f4219b4171f482619195007a5`.

Each process times one `Clerk.connect`, including bundle read/hash verification,
JavaScriptCore creation, real core execution, fixture HTTP and an authenticated
native session/user graph. Fixture parsing, synthetic-token construction and
configuration creation precede the timer. The app explicitly requires the
fixture session and user to be present; the collector rejects any report that
does not affirm authenticated state.

One unmeasured reset warms the local call path. Ten measured resets follow in
each process. Each must invalidate its captured email-code group and preserve
the authenticated session/user identities. Every process recorded two startup
HTTP requests and still exactly two after its resets. The operation interval
includes native dispatch, core mutation, native state application and async
resumption. It excludes the assertions following the await.

## Corrected measurement mismatch

The initial physical run used the previous harness at native revision
`461cb0c1c45078873923dedd57c7670174abf5bd`. Its client fixture had no sessions.
That run completed but did not satisfy the authenticated-startup measurement
definition. Its [signed-out report](ios-iphone-air-signed-out-latency.json) is
preserved separately, including its original mechanically computed budget
booleans; those booleans do not establish the intended authenticated boundary.
Its raw directory is `work/ios-physical-current-latency-raw/`.

The harness now selects the authenticated fixture in benchmark mode, supplies
a freshly timed synthetic token, checks authenticated native state and requires
that state in the collector's schema-version-2 report. The corrected run is a
different workload, not a retry intended to discard an anomalous timing.
Ordinary non-benchmark footprint mode remains signed out.

## Remaining gates

These timings meet the provisional startup and local-call limits on this device.
They do not measure real network or secure-storage latency, actual account
acceptance, OS authentication prompts, startup peak/steady memory, Expo/Hermes
overhead or UI responsiveness. Fresh processes do not imply a reboot or cold OS
filesystem caches; the first sample followed earlier diagnostic launches. The
full release performance gate still requires agreed budgets and representative
device/platform coverage.
