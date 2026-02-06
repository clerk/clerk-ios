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

- Use the `$swiftui-expert-skill` skill by default for SwiftUI feature work, reviews, and modern API adoption.
- Use the `$swiftui-view-refactor` skill for SwiftUI view structure work, including organizing view layout/sections, dependency injection, Observation usage, and refactors.
- Use the `$swift-concurrency` skill for general async/await, actor, `Sendable`, and isolation architecture guidance.
