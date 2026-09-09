# Environment assertion migration

This audit reads all 24 test declarations in the six old files under `Tests/Domains/Environment`. Environment hydration remains in `clerk-js`; the generated native environment is a required resource available after successful connection, and `environment.reload()` exposes its existing resource operation.

| Old assertions | Current disposition and evidence |
| --- | --- |
| `AuthConfigTests` (2): session-minter enabled and missing/default false | The shared environment suite checks the generated auth configuration for explicit true and absent values. |
| `AuthConfigDecodingTests` (3): all four native auth flags, missing defaults, backend-key encoding | Shared startup cases check all four enabled flags and their false defaults. The existing protocol suite also reloads the environment and observes flags becoming disabled. The native FAPI Codable encoder is removed; TypeScript owns server JSON and its own snapshot serializer. The old Swift backend-key serialization API is not retained. |
| `DisplayConfigDecodingTests` (4): development warning true/false/missing and backend-key encoding | Three shared cases preserve the canonical `showDevModeWarning` value and false default. The old Swift FAPI encoder is removed. Native spelling follows the TypeScript property. |
| `OrganizationSettingsDecodingTests` (5): missing, empty, partial, partial nested and full settings | Five shared cases check every asserted field: enabled, maximum memberships, forced selection, deletion permission, domain settings/role/enrollment modes, slug and creation defaults. Four packaged native startup cases check missing/partial settings and then a generated environment reload. |
| `EnvironmentServiceTests` (1): GET `/v1/environment` | Shared environment fixtures assert GET on the actual startup request. Native packaged startup and reload execute the same core path. No separate native environment service remains. |
| `EnvironmentTests` (4): refresh updates environment; concurrent coalescing; satisfied/unsatisfied refresh checkpoints | Native tests verify updated generated state after awaiting `environment.reload()`. The old `refreshEnvironment`/`ensureEnvironmentRefreshed(after:)` APIs and checkpoint/coalescing policy are removed. The canonical direct reload method has no promised equivalent checkpoint or concurrent-call coalescing contract. Lifecycle/connectivity recovery separately coalesces its own reloads; that is not a replacement promise for the old manual refresh API. |
| `EnvironmentCommerceSettingsDecodingTests` in `EnvironmentTests` (5): absent settings, user/organization billing flags, nullable Stripe publishable key, unknown extra field | Five shared cases preserve the exact selected billing fields and defaults. Reading these settings does not claim to implement native payment collection or complete every Billing flow. |

## Defect and validation

The new cases exposed that `OrganizationSettings.forceOrganizationSelection` was declared as required but left uninitialized. Missing, empty or partial organization settings caused embedded initialization to fail with `invalid_projection:EnvironmentResource.organizationSettings`. Initializing that field to false fixes the TypeScript object's contract; no Swift or Kotlin fallback is added. A supplied true value is still honored, including after reload.

The focused shared suite passes 16 cases and the complete embedded suite passes 181. The iOS contract target passes 50 tests and the Android packaged target passes seven. These validate successful startup, canonical defaults, stable environment wrapper identity, and changed settings before reload returns. These are fixture-backed behavior checks, not live Dashboard propagation or payment-processing evidence.

All six old environment files are retired after this assertion audit and the passing replacement checks. The removed Swift Codable models and refresh checkpoint utilities are not restored as a parallel environment implementation. Broader startup/identity, authentication, and response-ordering suites remain retained.
