# Agent guide for Swift and SwiftUI

This repository contains an Xcode project written with Swift and SwiftUI. Please follow the guidelines below so that the development experience is built on modern, safe API usage.


## Role

You are a **Senior iOS Engineer**, specializing in SwiftUI, SwiftData, and related frameworks. Your code must always adhere to Apple's Human Interface Guidelines and App Review guidelines.

## File headers

- Avoid author-attribution lines in headers (including assistant/AI attributions).

## Access control

- Internal is the default access level; do not specify it redundantly.
- Prefer access control on functions and properties, not on the extension.

## Documentation edits

- Do not add historical/contextual commentary in docs (for example, notes about why a line used to exist or past setup behavior).

## Skills usage

- Use the `$swiftui-pro` skill by default for SwiftUI feature work, reviews, and modern API adoption.
- Use the `$swiftui-view-refactor` skill for SwiftUI view structure work, including organizing view layout/sections, dependency injection, Observation usage, and refactors.
- Use the `$swift-concurrency` skill for general async/await, actor, `Sendable`, and isolation architecture guidance.

## GitHub metadata

- Do not add `codex`, `[codex]`, or other assistant branding to pull request titles.
- Do not add assistant branding to commit subjects, branch names, or release-note headings unless explicitly requested by the user.
- Use concise, human-readable pull request titles that describe the actual change.

## Cursor Cloud specific instructions

This is an Apple-platform SDK (iOS/macOS/tvOS/watchOS/visionOS). Cloud Agent VMs run Linux (x86_64), so the toolchain is split into what does and does not run here.

### Works on Linux (use these to validate changes)
- `make format-check` — SwiftFormat lint mode over all Swift files.
- `make lint` — SwiftLint. Requires a Swift toolchain because SwiftLint loads `libsourcekitdInProc.so` from it.
- `make check` — the CI gate: `format-check` + `lint` + the Ruby-based E2E contract checks (`check-e2e-hooks`, `check-e2e-selectors`, `check-e2e-phone-numbers`). It prints SwiftLint warnings (non-zero warning count is normal, e.g. "58 violations, 0 serious") and still exits 0 when passing.
- Command reference lives in `Makefile` and `CONTRIBUTING.md`; don't duplicate it here.

### Does NOT work on Linux (needs macOS + Xcode 26 + Apple SDKs)
- `swift build` / `swift test`, `make test`, `make test-ui`, `make test-e2e`, `make smoke-macos`, and the Xcode example apps under `Examples/`. `swift build` fails on Linux with `no such module 'UIKit'` / `AuthenticationServices` because `ClerkKit`, `ClerkKitUI`, and the `Nuke` dependency import Apple-only frameworks. Building, running the example apps, and running unit/UI/E2E tests must be done on macOS. Do not attempt to make these pass on Linux.

### Non-obvious environment notes
- The base VM image provides the system dependencies the Linux workflow needs: a Swift 6.2 toolchain on `PATH` (with its `lib` dirs registered via `ldconfig` so SwiftLint can load sourcekit) and `ruby` (for the E2E contract check scripts). These are baked into the snapshot, not installed by the update script.
- The pinned `SwiftFormat`/`SwiftLint` binaries live in the gitignored `.tools/` dir and are (re)installed idempotently by `make install-tools`, which the startup update script runs.
