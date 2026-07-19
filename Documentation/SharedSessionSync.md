# Shared Session Identity Synchronization

Shared-session synchronization treats the device token and `Client` as one identity value. Each application owns one discoverable Keychain slot and is the only writer allowed to update or delete that slot. Applications enumerate compatible peer slots, reduce their events to one winner, persist the complete winning identity atomically in app-local Keychain storage, and then apply it to memory.

## Identity Boundary

`ClerkIdentityController` is the single internal boundary for complete authentication identity transitions. Request preparation, network responses, Watch payloads, framework-driven device-token replacement, cache hydration, destructive cleanup, reconfiguration, and persisted Client-ID lookup enter through this controller. It owns response ordering, device-token response fences, the app-local identity operation queue, and the choice among legacy persistence, adopted atomic-local persistence, and active shared-session transport.

The controller does not absorb transport-specific protocols. `SharedSessionSyncCoordinator` owns owner slots, event generations, reduction, notifications, pending shared publication recovery, and peer reconciliation. Watch synchronization owns Watch versions, fingerprints, and transport metadata. Atomic-identity and shared-slot Security work remains behind actor-isolated I/O types.

Keychain enumeration and mutation are serialized off the main actor. One coordinator-owned operation chain handles local publications, durable-pending recovery, peer reconciliation, winner replication, owner-slot deletion, request identity capture, and network-response resolution. Request preparation requires a successful initial reconciliation, then captures the token, Client ID, response-generation context, and shared frontier as one queue-ordered snapshot.

## Event Order

Compatible, valid events use this lexicographic total order:

1. Higher logical generation.
2. At equal generation, an event with a server date over an event without one.
3. At equal generation with dates, the later server date.
4. Lexicographically greater origin owner identifier.
5. Lexicographically greater event UUID string.

The reducer deduplicates identical replicated events, excludes every payload involved in a conflicting reuse of one event ID, and separately reports the greatest valid observed generation. It does not use Client `updatedAt` or give sign-out special precedence.

## Pending Publication

The app-local atomic record may contain the accepted identity and at most one immutable pending publication event. The bounded pending intent is an approved part of the persistence model.

A local transition is first staged as that exact pending event. The same event ID, owner, generation, payload, and server date are then written to the app's owner slot. After reducing all compatible slots, the selected winner is committed as the accepted local identity and the matching pending intent is cleared. A retry reuses the exact event and never rebases it. New publication work is serialized behind pending recovery.

The record does not claim a transaction across two independent Keychain items. Process termination can still occur between the app-local stage and owner-slot write, or after the owner-slot write and before the accepted local commit. Restart recovery resolves both windows from the immutable pending event and observed slots.

## Response Payload Semantics

Successful frontend mutations can return an operation object in `response` and the authoritative Client snapshot in the sibling `client` field. Errors can carry the snapshot in `meta.client`. A removed Session plus a signed-out Client with an empty `sessions` array is a complete Client update, not an identity clear.

Null piggyback fields mean no Client update. A canonical `/v1/client` response with `response: null` and `client: null` also means no usable Client update, including backend database-maintenance responses. The native `DELETE /v1/client` contract is a separate explicit teardown: its `Authorization: Bearer ` response header clears the device token and complete local identity even if `response` contains the deleted Client snapshot.

One response checkpoint owns both the Authorization-token transition and the Client transition. Request sequence, server date, and device-token generation are evaluated once before either half can change, so a rejected Client response cannot still rotate the token. Because response work is serialized, its ordering watermark is committed only after the complete identity becomes durable and selected.

Framework-driven device-token replacement follows the same complete-identity rule. The new token is persisted, the previous Client and ordering date are cleared while independent Watch publication is suppressed, and one coherent identity-change event is emitted before canonical refresh. Watch never observes a new token paired with the previous Client.

## Watch Synchronization

Watch payloads are validated as complete token/Client transitions before publication. A Client snapshot must carry its paired nonempty token, a changed token without a Client clears the previous Client and requests a canonical refresh, and each Watch arrival reserves its place in the shared coordinator's serialized operation chain.

Watch version metadata is app-local. Read failures or corruption reject the identity update. One outgoing sync resolves pending metadata once and constructs the payload from that single snapshot. Before applying an incoming identity, the implementation durably stages its version, state, and payload fingerprint; it promotes the version and fingerprint only when the submitted identity becomes the selected shared winner. A candidate superseded by a concurrent peer winner discards its matching pending metadata so an exact retransmission can be evaluated again.

A credential-free Watch clear tombstone advances both Watch versions, replaces old fingerprints, and remains durable through explicit clears and strict reconfiguration so stale peer payloads or legacy metadata fallback cannot reseed the identity.

## Compatibility And Cleanup

Malformed, foreign-instance, owner/account-mismatched, and unsupported future-schema slots are excluded. A minimal schema-version header is decoded before current fields, so a future-schema own slot is preserved even if that schema renames or removes current fields. The SDK neither overwrites nor deletes it, while still adopting compatible peer winners locally.

Adoption runs only after the previous runtime's writers are stopped and drained. Existing atomic identity wins, followed by a nonempty token from app-local legacy storage, previous bundle-local storage, and legacy shared storage. Legacy token, Client, and date fields have no common revision, so adoption never promotes their apparent tuple to an atomic identity.

Destructive local cleanup immediately fences prepared responses and clears the live atomic identity. It invalidates older identity revisions, freezes cache persistence, drains coordinator and cache writers, deletes only this application's owner slot, scrubs reusable credentials from legacy shared storage, and performs final app-local deletion before releasing the reconciliation barrier. If owner-slot withdrawal fails, the clear reports the failure and leaves shared reconciliation and request capture barriered until a later clear retry succeeds.

Reconfiguration performs credential adoption only after draining the old runtime and only when the normalized publishable key permits identity preservation. Destructive or cross-key transitions clear the destination and write the adoption marker without importing legacy credentials. The old owner slot remains available for rollback through fallible setup and is withdrawn as the final required boundary before the new runtime is committed. The owner slot is preserved only when the key and complete slot topology remain unchanged; peers are never deleted.
