# Review guide

This file tells AI reviewers what matters in this repository. `AGENTS.md` has the coding rules (strings, comments, device evidence), and this file doesn't repeat them.

## What counts as a failure

- A session token, client JWT, or device token is lost, leaked, or written to the wrong place. The code lives in `Sources/ClerkKit/Storage/Keychain/`, `Sources/ClerkKit/Identity/`, `Sources/ClerkKit/Domains/Auth/Session/`, and `Sources/ClerkKit/Networking/Middleware/ClerkDeviceTokenResponseMiddleware.swift`.
- A Keychain read error is treated as a missing item. That signs the user out or skips a migration. SwiftLint's `keychain_read_try_optional` rule catches `try?`, so look for the other forms, such as a `catch` that returns `nil`.
- A secret reaches a log or an error message. Check URL user info, query items, form fields such as `code=`, and errors that carry a URL. Redaction is in `Sources/ClerkKit/Logging/ClerkLogRedaction.swift`.
- Bad configuration input traps instead of throwing. `ConfigurationManager.swift` and `DependencyContainer.swift` must throw `ClerkInitializationError` for a malformed key or URL.
- A `public` declaration in `Sources/ClerkKit` or `Sources/ClerkKitUI` is removed or changes shape. Say which apps break and whether the change needs a major version.
- An auth flow leaves sensitive fields in `AuthState` after it ends, or an async page load and a mutation in a paged list overwrite each other.
- A workflow change in `.github/workflows/` skips a required check, runs a check against the wrong base, or gives a job secrets that a fork PR can reach.

## Always check

- Every new log line or error description that includes a URL, a request body, or a server response goes through redaction.
- A new network call that retries has a limit. Rate-limit retry is in `ClerkRateLimitRetryMiddleware.swift`.
- When a PR changes how a feature behaves, the page for that feature under `.claude/skills/verify-clerk-ios/features/` still describes it. Stale gotchas there have misled agents before.
- A finding still holds at the head commit. Read the current file before you post.

## Don't flag

- Runner architecture guards in workflows. Every macOS runner this repository uses is Apple silicon.
- Timing windows, exit codes, or leftover child processes in `e2e-tests/` and `.github/scripts/`, when the worst case is one failed or retried run. Flag them only when you can name the input that reaches the failure.
- Requests for a hosted SwiftUI view test when the view calls a helper that has its own test. The device evidence in the PR description covers the wiring.
- E2EHost screens that match the clerk-android test app on purpose.
- A claim about a GitHub or Clerk API response format that rests on docs alone. Cite a real response or leave it out.
- Style that SwiftFormat or SwiftLint would change. `make check` runs both.

## Skip these paths

- `Tests/UI/__Snapshots__/**` (recorded PNGs)
- `**/*.xcassets/**`
- `Examples/**/project.pbxproj`
- `e2e-tests/package-lock.json`

Don't skip the `.xcstrings` catalogs. Translations need review, as `AGENTS.md` says.

## How to report

- Give a file and line for every finding. Don't guess a path.
- Mark each finding Important, Nit, or Pre-existing. Pre-existing means the PR didn't change that code, so the author doesn't own it.
- Keep Nits to a few per PR.
- Start with a summary that counts findings by severity. When there are none, write "No issues found."
