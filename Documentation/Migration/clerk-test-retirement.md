# Legacy Clerk suite retirement

`Tests/Core/ClerkTests.swift` is retired after reviewing all 92 declarations and
their assertion bodies, finishing the current presentation checks and verifying
its helper boundary. The source matched baseline
`02f98f89a19b6c079517c9aae07df7edd0e600e5` byte for byte: 3,223 lines, SHA-256
`559945f1d42a8705616f931a0c8db0367b0ecfb538307b38f11c5af0053347b1`.
The [baseline inventory](legacy-tests.json) remains unchanged.

The [startup/storage audit](clerk-storage-test-audit.md) maps the first 31
declarations; the [presentation/readiness audit](clerk-auth-flow-test-audit.md)
maps the remaining 61. Their table entries were compared with the inventory:
all 92 names occur exactly once, with no omissions or extra entries. This is an
assertion disposition map, **not a claim that 92 replacement tests passed**.

## Retained behavior and changed APIs

The audit reproduced and fixed presentation defects involving root gating,
external-session work, enrollment token replacement, mutable attempt identity,
and replay of a later attempt after enrollment finishes. The current packaged
suite has 24 declarations covering actual generated connection, authentication,
finalization, session reload/selection, sign-out and HTTP rejection outcomes.
The final complete UI runs pass 159 tests on macOS and 170 on iOS Simulator.
Storage, credential clear, installation markers and request ordering have their
own linked regression evidence, including real Keychain process boundaries.

Mutable singleton configuration, arbitrary client/environment assignment,
global storage clearing, whole-client offline snapshots, native request-owner
properties, identity-update enums, semantic-rejection resolvers and activation
handles have no corresponding entry points in this major. The old forged-state,
private revision/call-count and synchronous mutation assertions retire with
those interfaces. A synthetic active session without a user did not reproduce
through the new resource path; it is not claimed as passing coverage. The
selected-session user guard remains, and identity-loss checks prevent obsolete
work from completing.

Hosted portal authentication and live shared-session/watch replication remain
explicitly unavailable. Their old activation markers and publication assertions
are product-gap evidence, not successful migration proofs. The selected major's
credential record does not persist or replay UI completion intent. Live
generated resources also do not provide immutable historical field values from
a prior native value-type snapshot; stable presentation work and screen tokens
provide the ownership boundary instead.

## Helper boundary

All nine file-private helper types were read: `ClearRecoveryTargetProvider`,
`SuspendingCacheKeychain`, `DeleteFailingKeychain`, `LocalIdentityOperationGate`,
`SuspendingIdentityStore`, `ClearTrackingSlotStore`, `MissingEntitlementSlotStore`,
`SilentSharedSessionNotifier`, and `DataFailingKeychain`. Their names and the
private `installationMarkerDefaultsSuiteName` function have no callers outside
this file in current Swift sources. The two nested snapshot wrappers and the
suite's configuration, session, environment, completion, recovery and wait
factories are local to `ClerkTests`; no external suite reference was found.
No shared test-support file is removed in this retirement.

`ClerkKitTests` remains registered in the default package graph. The remaining
shared-adoption suite and its helper files still require final migration work;
this retirement does not hide that target or claim that default `swift test`
passes. Signed access-group attribution, live configured-instance integration,
physical system prompts, real released-app upgrades and physical performance
budgets remain separate release requirements. Retiring this reviewed file does
not satisfy those gates.
