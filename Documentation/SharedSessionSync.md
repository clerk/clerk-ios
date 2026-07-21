# Shared Session Sync Contract

Shared-session sync treats the device token and `Client` as one authentication identity. `ClerkIdentityController` is the single boundary for identity changes from cache hydration, requests, network responses, Watch payloads, device-token replacement, clears, and reconfiguration. It chooses the active persistence mode and fences response ordering.

`SharedSessionSyncCoordinator` owns shared transport: owner slots, logical generations, notifications, pending publication recovery, peer reconciliation, and slot deletion. Each app writes only its own owner slot, enumerates compatible peer slots, reduces valid events to one winner, persists that winner atomically in app-local Keychain storage, then applies it to memory.

## Event Ordering

Compatible events are ordered by:

1. Higher logical generation.
2. Presence of server date.
3. Later server date.
4. Lexicographically greater owner identifier.
5. Lexicographically greater event UUID string.

The reducer deduplicates identical replicated events and rejects conflicting reuse of an event ID. It does not inspect `Client.updatedAt` and does not give sign-out special priority.

## Pending Publication

The app-local atomic record may contain one accepted identity and one immutable pending publication event. Local publication stages that pending event, writes the same event to the app owner slot, reduces all compatible slots, then commits the selected identity and clears the matching pending intent.

There is no transaction across the app-local record and owner slot. Restart recovery must resolve either side of a partial publication from the immutable pending event plus observed slots.

## Response Payloads

Frontend mutation responses can carry the operation result in `response` and the authoritative Client snapshot in sibling `client`. Error responses can carry the snapshot in `meta.client`. A removed Session plus a signed-out Client is a normal Client update, not an identity clear.

Null piggyback fields mean no Client update. A canonical `/v1/client` response with `response: null` and `client: null` is also preserve/no-update, including backend database-maintenance responses. Native client deletion is the explicit clear path: `DELETE /v1/client` clears the device token and identity when the response has `Authorization: Bearer `.

Request sequence, client-response generation, shared-session base generation, canonical-client flag, and request device token form one response checkpoint. A response may advance ordering only after its complete identity transition is durable and selected.

## Watch Sync

Watch payloads are complete identity transitions. A Client snapshot must have its paired nonempty token; a changed token without a Client clears the previous Client and asks the phone to refresh. Incoming Watch versions are staged with state and payload fingerprints, then promoted only if the submitted identity wins.

Watch metadata state is a durable string protocol with `set` and `cleared`. Versionless legacy payloads remain accepted only when no current or pending version exists.

## Clear And Reconfigure

Destructive local clear fences prepared responses, clears the live atomic identity, drains SDK writers, deletes this app's owner slot, scrubs reusable legacy credentials, and releases the local-clear barrier only after shared transport is withdrawn. If owner-slot withdrawal fails, reconciliation and request capture remain barriered until a clear retry succeeds.

Reconfiguration adopts credentials only after draining the old runtime and only when the normalized publishable key permits preservation. Cross-key or destructive transitions clear the destination and do not import legacy credentials.
