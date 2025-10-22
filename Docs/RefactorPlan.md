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
- `Features/*`: folders per bounded context (`Auth`, `Session`, `UserProfile`, `Organization`, `Identification`). Each exposes:
  - `Interfaces`: public protocols and models.
  - `UseCases`: async workflows orchestrating services (often actors to manage state).
  - `DataSources`: networking/storage implementations that conform to the feature interfaces.
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

## Prototype Scope (Phase 0)
- **Milestone A – Target scaffolding**: Add `ClerkKit` and `ClerkKitUI` targets to `Package.swift`, move minimal entry points, set up shared build settings, and ensure current tests compile with stubs.
- **Milestone B – FactoryKit consolidation**: Audit current FactoryKit registrations, relocate them into the new targets, and document override points for tests/previews.
- **Milestone C – Networking spike**: Build the initial `HTTPClient` with middleware pipeline, response decoding, and error mapping; cover with Swift Testing using fixture-driven mocks.
- **Milestone D – Auth flow pilot**: Rebuild sign-in flow using the new networking stack, exposing async façades and async streams for session changes.
- **Milestone E – Preview harness**: Create preview helpers plus sample data to render a representative subset of ClerkUI views without live services.
- **Milestone F – Custom container (deferred)**: Once earlier milestones harden, revisit rolling a bespoke container to replace FactoryKit with richer scoping and validation.

### Exit Criteria
- New module layout compiles and existing FactoryKit wiring functions within it.
- Networking spike and auth pilot exercise async APIs end-to-end (network -> use case -> published state).
- SwiftUI preview compiles with new dependency injection override guidance using mock data.

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
