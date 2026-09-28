# Agent Guidelines

## Code comments

- Do not write comments that explain code. No `//` or `/* */` comments describing what code does or why it does it. Put that intent in names, types, and tests. If behavior depends on a non-obvious constraint, cover it with a test.
- Allowed: `///` doc comments on declarations, `// MARK:` section markers, SwiftLint and SwiftFormat directives, license notices, and file headers.
- When you change behavior that a doc comment describes, update the doc comment.
- `make lint` enforces this through `.swiftlint-comments.yml`.
