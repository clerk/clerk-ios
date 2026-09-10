# Callback assertion migration

This audit reads `ExternalAuthUtilsTests` (6 declarations), `MagicLinkTests` (6, with parameterized routes), `MagicLinkServiceTests` (1) and `MockMagicLinkServiceTests` (1) at baseline `02f98f89a19b6c079517c9aae07df7edd0e600e5`. The old `ClerkURLRoute`, `URL+Ext` and `MagicLink` implementations were also inspected to establish actual normalization and parameter precedence.

## Compatibility fixes

The new TypeScript handler initially ignored callbacks whose email-link parameters were in the fragment, rejected the old equivalent empty/root-slash path forms, and compared custom-scheme hosts case-sensitively. Three packaged-core tests reproduced those failures. `NativeMagicLink` now preserves the old scheme/host and root-path behavior and reads fragment parameters after query parameters. It retains the newer username/password, port and configured-query checks. Non-root paths remain exact: `/callback/extra` is not accepted as `/callback`.

The existing persisted-verifier/flow checks, request deduplication, reset fencing, terminal-error cleanup and explicit session adoption still apply. Route normalization is implemented once in TypeScript; no second native callback parser is introduced.

## Assertion dispositions

| Old assertions | Current disposition |
| --- | --- |
| Nonce present alone or among other query parameters | Real future-style SSO tests verify nonce forwarding in the reload request for both sign-in and sign-up. |
| No nonce, empty nonce, or no query | The shared SSO transport reloads the resource without a nonce. An empty nonce is omitted from the request rather than exposing the old helper's empty-string return value. |
| Nonce in query with a fragment | The query nonce is preserved. A fragment does not replace an OAuth query nonce. |
| Email-link flow/approval in query or fragment | Shared email-link tests verify actual completion and canonical resource results using either form. Both native packaged-core tests additionally exercise a fragment callback. |
| Configured custom scheme, empty/root path and root path with fragment | Preserved and regression-tested; mixed-case scheme/host is also covered according to the old implementation. |
| Single-slash URI, wrong host, extra path, wrong scheme | Return null before HTTP, preserving the saved verifier. |
| Missing flow id throws from `MagicLinkCallback.init` | That private initializer is removed. The new public routing API returns null for incomplete/unrecognized callbacks; the test verifies it does not consume storage or issue HTTP. This is not an assertion that the old initializer's signature/error policy survives. |
| `MockMagicLinkService.completeUsesInjectedHandler` | A removed native service mock testing its own closure and DTO equality. Ordinary completion now executes TypeScript. The shared sign-in email-link test validates the actual ticket-to-sign-in flow; the sign-up test validates the resource-returning form. |
| `MagicLinkService.completeCanEstablishClientWhenTokenless` | The POST completion request is exercised by the new core suite. Its old `clerkStartupClientRefreshTakeoverID` assertion belongs to the removed native startup coordinator. The completed identity and authentication resource audits now retire this private assertion. The old test did not assert accepted client state or persisted credentials. |

Validation: 26 shared callback tests pass (16 email-link, 10 SSO), and mobile-runtime type checking passes. The newly pinned native package passes 44 tests on iOS Simulator and both Android packaged-core tests. The native callback assertions confirm completion without implicit activation and verifier cleanup. They do not prove delivery by a real mail client, associated-domain registration, or a live old-major app upgrade.

`ExternalAuthUtilsTests`, `MagicLinkTests`, and `MockMagicLinkServiceTests` are retired after the passing replacement checks. `MagicLinkServiceTests` is now retired under the [authentication resource audit](auth-resource-test-audit.md), after the separate identity audit established the new startup contract. The larger Auth state suite remains retained.
