# Resource results after deletion

The generated `OrganizationMembership.destroy()` returns the removed membership. The canonical TypeScript implementation previously declared that result but returned `undefined`, causing `invalid_bridge_value` after an otherwise successful deletion. It now returns the hydrated resource after deletion completes. A full resource response supplies updated fields; a minimal `deleted: true` receipt preserves the last readable fields. The response's client updates the user's membership collection and active organization before the call completes.

`NativeCoreContractTests/OrganizationMembershipTests.swift` exercises both response forms with the packaged JavaScriptCore runtime. It checks the effective DELETE path, membership user ID, session query, typed result, metadata, readable nested organization after deselection, updated user collection, and a subsequent operation. Both cases failed before the fix and pass afterward. The complete contract suite passes on macOS (68 tests) and iOS Simulator (65 tests).

Two baseline assertions at `02f98f89a19b6c079517c9aae07df7edd0e600e5` were reviewed:

| Baseline declaration | Current evidence |
| --- | --- |
| `OrganizationTests.destroyOrganizationMembershipUsesOrganizationServiceDestroyOrganizationMembership` | The generated operation sends the membership's organization ID and public user ID in the actual HTTP path. The removed native service forwarding contract is not retained. |
| `OrganizationServiceTests.destroyOrganizationMembership` | The packaged runtime sends an effective DELETE and the active `_clerk_session_id`; TypeScript uses POST with `_method=DELETE`. Both accepted response forms are checked. |

The remaining assertions in those files have not been fully audited, so both legacy files remain retained. Behavior for a membership without a public user ID remains unresolved.

The shared `Client.removeSessions()` implementation had the same declared-result mismatch and now returns its updated client. Its source test checks that public result and cleared session state. This does not restore a native `Client` root.

Shared evidence: all 227 embedded-core tests and 17 focused source tests pass, including rejected membership deletion retaining canonical state. Packaged core revision: `86c89414f7ea26ba3de14ab65ba7ea5407c2e95a`; bundle SHA-256: `34808311909b099c643ad5c85209f54381346d74bf72467feef0397fbe759e92`. The generated API contract is unchanged. These are fixture checks, not live organization deletion, device upgrade, or release-performance evidence.
