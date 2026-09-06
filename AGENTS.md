# Agent guide

This is the Clerk iOS SDK: a multi-platform Swift package (`ClerkKit`, `ClerkKitUI`) plus example apps. See `CONTRIBUTING.md` for setup, formatting, lint, and tests.

## Conventions

- Avoid author-attribution lines in headers (including assistant/AI attributions).
- Internal is the default access level; do not specify it redundantly.
- Prefer access control on functions and properties, not on the extension.
- Do not add historical/contextual commentary in docs (for example, notes about why a line used to exist or past setup behavior).
- Do not add assistant branding to pull request titles, commit subjects, branch names, or release-note headings unless explicitly requested.
- Use concise, human-readable pull request titles that describe the actual change.

## Skills

Load a skill only for the matching task:

- `$swiftui-pro` when reviewing or modernizing SwiftUI
- `$swiftui-view-refactor` when restructuring a SwiftUI view's layout, dependencies, or Observation usage
- `$swift-concurrency` when changing async/await, actors, `Sendable`, or isolation
- `$swift-testing-expert` when adding or changing Swift Testing tests

## Local checks

`make test` uses mocked APIs and has no production access. Run `make check` and `make test`, fix failures caused by the requested change, and rerun affected tests without asking for approval.
