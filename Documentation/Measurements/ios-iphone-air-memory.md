# Physical single-owner memory — September 10, 2026

Three matched Baseline/Embedded pairs completed on iPhone Air (iPhone18,4),
iOS 26.6.1 (23G83), using six fresh release app processes. App order alternated
between pairs. All processes reported nominal thermal state and low-power mode
disabled. No debugger, explicit garbage collection or allocator purge was used.

| Pair | Sampled startup footprint delta | Kernel startup peak delta | Steady footprint delta | Closed footprint delta |
| --- | ---: | ---: | ---: | ---: |
| 1 | 16.266 MiB | 16.266 MiB | 12.922 MiB | 2.750 MiB |
| 2 | 15.922 MiB | 16.094 MiB | 12.344 MiB | 2.344 MiB |
| 3 | 16.188 MiB | 16.188 MiB | 15.375 MiB | 5.313 MiB |

Startup columns subtract the baseline maximum from the embedded maximum in the
startup phase. The kernel column uses the process-lifetime footprint high-water
mark observed during that phase; it can include memory charged before sampling
began. Steady and closed columns subtract phase medians. The third pair's higher
retained footprint is preserved, not filtered or replaced by a better run.

These observed footprint deltas are below the provisional 64 MiB startup and
32 MiB steady limits on this device. That does not close representative-platform
coverage, heap attribution or repeated connect/close stability requirements.

## Measurements and raw evidence

The [summary](ios-iphone-air-memory.json) retains per-phase minima, medians and
maxima, sample counts and spans, actual sampling gaps, process IDs, device state,
owner lifecycle assertions, app hashes and raw-file hashes. Its six linked gzip
files contain every raw sample. Decompressing each file reproduces the exact
original report SHA-256. No launch or sample was retried or discarded.

The sampler requested a 5 ms interval with 1 ms leeway on a separate dispatch
queue. Each app produced 2,268–2,329 samples. The largest actual sampling gap was
6.065 ms. Sampling starts before fixture preparation and connection, so a
main-thread startup does not stop the sampling queue. The kernel high-water
field adds evidence about peaks between snapshots; pair 2 demonstrates why it
is retained alongside sampled values.

Both apps use the same source, view, sampler and build configuration. Baseline
does not link JavaScriptCore directly or bundle Clerk's core; Embedded does.
Embedded creates exactly one authenticated fixture owner, executes 50 generated
resets without additional HTTP, waits three seconds, and records a one-second
steady window. It then closes the owner, releases the fixture and waits five
seconds before recording a one-second closed window. A weak reference confirms
the native owner was released in every embedded process.

Additional resident memory was 29.266–33.797 MiB at steady state and
29.469–33.891 MiB in the closed windows. These values remain in the report;
they are not substituted for physical footprint. The report also retains VM
internal, external and compressed bytes as separate fields. They are not a
breakdown of the Swift and JavaScript heaps, and must not be added to footprint
as independent allocations. Apple's [memory guidance](https://developer.apple.com/documentation/xcode/reducing-your-app-s-memory-use)
and [memory diagnostic explanation](https://developer.apple.com/videos/play/wwdc2021/10180/)
describe why memory footprint and clean resident pages are different measures.

## Provenance and limits

The measured source revision is `9601eccb5981fbe4cba164049556c91ec5ea7f0c`.
Both apps were rebuilt after the repository's formatting hook, signature-verified
and installed from the same Release products directory. The build uses Swift
`-O` whole-module compilation, arm64 and development signing. The source hash is
`960c6a032c08fa3c6385dc0cffb14e0bad93af59420a7ce9fdbf9c6fae1a07c7`;
both executable hashes are in the summary. The embedded core remains revision
`0b97ed0a260429dda4f230e32bb7e94fde3097f4`, SHA-256
`86d665dd87bc188352594cf80a5c0c5927348d84d9de6382e927d4da8abc9cd3`.

The local collection command is documented in `Examples/CoreFootprint/README.md`.
Uncompressed reports, launch receipts and console logs remain in the task's
`work/ios-physical-memory-raw/` directory, with the collection log at
`work/ios-physical-memory.log`. Report serialization happens after sampling stops.
The sampling buffer itself contributes to both app measurements.

This is one device and three pairs. It excludes real HTTP, secure credentials,
OS prompts, native Clerk UI and Expo/Hermes. The closed windows show normal
post-close process memory and native-owner release; they do not prove that every
engine allocation was returned to the OS or that repeated owner creation reaches
a stable plateau. No forced collection was used to hide retained memory. VM
categories do not supply separate native/JavaScript heap attribution, and memory
samples do not establish UI responsiveness. Those release checks remain open.
