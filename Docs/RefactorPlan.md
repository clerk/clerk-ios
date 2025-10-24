# Clerk iOS Refactor Plan

## Vision
- Deliver a modernised core that embraces Swift concurrency and removes legacy third-party dependencies while keeping ClerkUI largely intact.
- Split the package into focused products so apps can choose only the logic (`ClerkKit`) or the UI surface (`ClerkKitUI`).
- Provide first-class support for Swift Testing, SwiftUI previews, and deterministic dependency injection.

## Guiding Goals
- Async/await-first APIs with cancellation awareness and actor isolation where shared mutable state exists.
- Container-driven dependency injection with explicit registration and override points for tests and previews.
- Minimal runtime dependencies in `ClerkKit`; third-party UI helpers (Nuke, PhoneNumberKit) remain confined to `ClerkKitUI`.
- High testability through protocol seams, fixtures, and lightweight fakes.
- Easy preview authoring by bundling ready-made preview containers plus sample data.

## Module Blueprint

### Products and Targets
1. `ClerkKit` (core logic)
   - Depends on Foundation, Swift Algorithms (evaluate necessity), URLSession, Keychain APIs.
   - Declares internal submodules (namespaces) for `Auth`, `Sessions`, `User`, `Organization`, `Telemetry`, and `Configuration`.
   - Exposes async APIs via façade types (`ClerkClient`, `SessionStore`, etc.) backed by injected services.
2. `ClerkKitUI` (presentation)
   - Depends on `ClerkKit`, SwiftUI, `Nuke` (image loading), `PhoneNumberKit`.
   - Provides view models that use injected `ClerkKit` façades; keeps existing view hierarchy with adapted signatures.
   - Offers preview-specific helpers and sample data so UIs render without networking.

### Internal Package Structure (`ClerkKit`)
- `Core`: lightweight kernel containing the dependency container, configuration DSL, logging hooks, and shared protocols (clock, uuid generator).
- `Networking`: home-rolled HTTP client using `URLSession` with middleware pipeline (auth headers, retries, logging).
- `Storage`: keychain/token secure storage, cache providers, persistence strategy.
- `Domains/*`: bounded contexts (`Auth`, `User`, `Organization`, `Client`, `Environment`, etc.). Each exposes:
  - `Interfaces`: public protocols and models.
  - `UseCases`: async workflows orchestrating services (often actors to manage state).
  - `DataSources`: networking/storage implementations that conform to the domain interfaces.
- `Support`: utilities, error definitions, and strongly typed configuration.

### Cross-Target Dependencies
- `ClerkKit` is dependency-free beyond Apple frameworks and vetted core libs (consider dropping Swift Algorithms if unused in the new design).
- `ClerkKitUI` is the only target allowed to import UI-specific dependencies; enforce this via target membership checks.
- Shared resource bundles (localizations, themes) migrate to `ClerkKitUI` to keep the core lightweight.

## Dependency Injection Strategy
- Continue leveraging FactoryKit during the initial refactor phase to keep churn low while logic is moved into the new targets.
- Define clear protocol boundaries for each feature so FactoryKit registrations remain explicit and test-friendly.
- Document a path to a bespoke container once the rest of the rewrite stabilises; that work shifts to a later milestone to minimise disruption.
- Provide guidance for overriding FactoryKit registrations in Swift Testing and SwiftUI previews to keep the new APIs mockable.

## Concurrency Model
- Default to async functions returning domain-specific result types (`Result<Value, ClerkError>` where propagation is desired).
- Use actors for shared state (session refresh, token cache) to guarantee thread safety.
- Long-running event streams (session updates, user changes) exposed as `AsyncStream` so UI can observe updates.
- Adopt cooperative cancellation (`withTaskCancellationHandler`) for flows triggered from UI.

## Networking Stack Highlights
- `HTTPClient` protocol with async `send(_:)` method returning a `HTTPResponse` wrapper.
- Plug-in middleware chain (auth headers, telemetry, logging, retry, decoding).
- Request builders per feature using strongly typed endpoints; responses decoded via `Decodable` with error mapping to `ClerkAPIError`.
- Built-in test double (`MockHTTPClient`) driven by fixtures for Swift Testing.

## Testing & Tooling
- Standardise on Swift Testing in a new `ClerkKitTests` target; keep XCTest only where necessary until full migration.
- Provide factory functions for common fixtures (user, session, tokens) under `Tests/Fixtures`.
- Bundle helper assertions for async sequences and actors.
- Add contract tests per feature that wire the container with in-memory adapters to validate choreography.

## Preview & Mock Support
- Ship `PreviewClerkContainer` with canned services and deterministic data.
- Provide SwiftUI `EnvironmentKey` helpers to inject dependencies into views.
- Include sample JSON payloads in `ClerkKitUI/Previews` for realistic data without hitting network.
- Keep model mocks declared with Swift’s `package` access level so `ClerkKit`, `ClerkKitUI`, and all test targets share a single fixture surface while keeping the mocks out of the public API. SwiftUI previews now import `ClerkKit` directly and use the shared mocks without extra wrapper helpers.

## Roadmap (Phase 0 → Phase 1)
- **Milestone A – Target scaffolding ✅**: Added `ClerkKit`/`ClerkKitUI` products and preserved a compatibility target.
- **Milestone B – FactoryKit consolidation 🔄**:
  - Convert remaining services (Session, User, Organization, Environment) to protocol-first registrations. *(Session/User/Environment/Organization complete.)*
  - Define a central helper for test/preview overrides to reduce duplication. *(TestContainer helper prepared.)*
  - Document DI ownership per domain to prepare for a future container swap.
- **Milestone C – Networking spike ⏭️**:
  - Implement request middleware pipeline (auth headers, encoding, logging hooks). ✅
  - Add response validation middleware with typed error conversion. ✅
  - Prototype retry/backoff strategy and instrumentation hooks (metrics/events). ✅ (legacy retry/backoff and network telemetry restored)
  - Cover the home-grown client with Swift Testing via `MockingURLProtocol`. ✅
  - Document middleware responsibilities in code (request preprocessors, response validators, retriers). ✅
- **Milestone D – Auth flow pilot ⏭️ (no new features yet)**: Rebuild sign-in/sign-up flows atop the new networking client, sticking to existing functionality; defer feature additions until the refactor is complete.
- **Milestone E – Preview harness ⏭️ (existing scope only)**: Provide deterministic preview container and sample data that mirror current behaviour; enhancements wait until post-refactor.
- **Milestone F – Custom container (deferred)**: Evaluate replacing FactoryKit after DI boundaries settle and once we resume feature work.

### Exit Criteria
- Domain modules depend on protocol-based services with clear testing hooks.
- Networking spike validates request/response middleware via Swift Testing (no third-party client dependency).
- Preview harness offers stubbed data for core flows without runtime networking.

## Breaking Changes (Draft Outline)
- **Package restructuring**: Product name changes from `Clerk` to `ClerkKit`; UI entry points migrate to `ClerkKitUI`. Apps must update imports and target references.
- **Async API surface**: All major services (sign-in, session, user management) expose async methods. Callback-based APIs removed. Clients need to adopt `await` and handle cancellation.
- **Dependency configuration**: FactoryKit registrations become explicit per module, replacing previous global singletons. Future bespoke container work will ship once stabilised; consumers should plan for a configuration entry point.
- **Networking customisation**: Public configuration points (`HTTPMiddleware`, retry policy) replace previous Get-specific hooks. Apps with custom URLSession behaviour must re-register middleware.
- **Telemetry hooks**: Unified observer protocol replaces scattered delegate callbacks; adopt new event enum for analytics integrations.
- **Image loading**: UI now uses Nuke under the hood; apps overriding image loaders must conform to the new `ImageLoading` protocol provided by `ClerkKitUI`.

## Progress Log
- 2025-10-22: Captured current structure, drafted refactor blueprint, and outlined prototype scope plus breaking changes.
- 2025-10-22: Split legacy sources by moving `ClerkUI` into the new `ClerkKitUI` target, renamed the core source directory to `ClerkKit`, and kept a thin compatibility target exporting both modules.
- 2025-10-22: Restructured core sources (`Networking`, `Domains/Auth/Session`) to match the new architecture and verified a targeted test subset (`ProxyConfigurationTests`) while keychain-dependent suites remain temporarily disabled in CLI runs.
- 2025-10-22: Migrated `Client`, `Environment`, `SignIn`, `SignUp`, `User`, `Passkey`, and related resource models into domain namespaces; introduced a test-only keychain + API client registration helper so CLI tests can run without SimpleKeychain crashes.
  - Locale is automatically attached to sign-in creation requests (with override support) to match recent main-branch behaviour.
- 2025-10-23: Introduced `SignInServiceProtocol`/`SignUpServiceProtocol` abstractions with concrete implementations registered in the container to standardise async API usage ahead of the networking rewrite.
- 2025-10-23: Drafted networking middleware interfaces and planned next steps for replacing the `Get` dependency with a home-grown client.
- 2025-10-23: Continued DI consolidation by introducing service protocols for sessions, users, and environment fetching; container registrations now expose protocol types for easier testing/preview overrides.
- 2025-10-23: Replaced legacy request processors with concrete networking middleware types, introduced a reusable middleware pipeline, and updated tests to exercise the new request path mechanics.
- 2025-10-23: Added Swift Testing coverage for request/response/retry middleware (proxy/header/form encoding, auth event emission, invalid auth client refresh, and device assertion retries).
- 2025-10-23: Restored debug request/response logging and the legacy rate-limit/backoff retry behaviour inside the middleware pipeline, including tests that drive the new logging and retry paths.
- 2025-10-23: Converted legacy static mocks to `package` scope for cross-target reuse while SwiftUI previews import `ClerkKit` directly, eliminating the need for dedicated preview wrappers.
