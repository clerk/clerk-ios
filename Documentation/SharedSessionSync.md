# Identity Persistence and Sync

The device token and `Client` form one authentication identity. The token names a server-side Client, so two apps or devices holding the same token share one Client and only need to agree on the newest snapshot of it. The server stays the authority: whenever state is in doubt, the SDK keeps a token and refreshes the Client.

## One Record

`ClerkIdentityStore` persists `{deviceToken, client, serverDate}` as a single Keychain item, along with a `revision` UUID that changes on every write. Because it is one item, a reader never sees a token paired with another identity's Client. Saving an identity without a token deletes the item.

The record lives in the configured Keychain (`KeychainConfig.service` and `accessGroup`) and records which Clerk instance wrote it; a record for another instance is ignored and replaced by the next write. With an access group, every app and extension in the group that runs this SDK version reads and writes the same item; apps on earlier SDKs keep their own storage (see Migration From Earlier Versions). Two exceptions keep the identity app-local, with sharing off: an app that adopted shared-session sync in SDK 1.5 and then turned it off, and an app that lacks the group entitlement. Enabling `sharedSessionSync` without an access group makes `Clerk.configure` throw.

A `Client` that no longer decodes, for example one written by a newer SDK in another app, is dropped while the device token is kept, so the next refresh restores it instead of signing the user out.

`ClerkIdentityController` is the only writer. `commit` writes the record, then updates memory. A write that changes the device token must succeed, because losing a new token signs the user out on the next launch; other write failures are logged and the next response rewrites the record. Keychain access is synchronous on the main actor.

## Shared-Session Sync

With `sharedSessionSync: .enabled`, the controller also:

1. Re-reads the record's revision before capturing a request identity, applying a response, applying a Watch transition, or replacing the device token, and on foreground. If another process wrote since this app last read or wrote, it adopts that identity.
2. Posts a Darwin notification after each write. Other apps re-read on receipt. Reading does not post, so notifications cannot loop.

Adopting another app's identity with a different token fences in-flight responses (`clientResponseGeneration`), so a response for the old token cannot overwrite it. Adopting a newer snapshot for the same token sets a server-date floor in `ClientResponseOrderingGate`, so a response the server produced earlier cannot overwrite it.

Two apps writing at the same instant is last-writer-wins; the next response or refresh corrects the Client.

## Response Payloads

Frontend mutation responses can carry the operation result in `response` and the authoritative Client snapshot in sibling `client`. Error responses can carry the snapshot in `meta.client`. A removed Session plus a signed-out Client is a normal Client update, not an identity clear.

Null piggyback fields mean no Client update. A canonical `/v1/client` response with `response: null` and `client: null` is also preserve/no-update, including backend database-maintenance responses. Native client deletion is the explicit clear path: `DELETE /v1/client` clears the device token and identity when the response has `Authorization: Bearer `.

Request sequence, client-response generation, canonical-client flag, and request device token form one response checkpoint.

## Watch Sync

Each device sends its complete auth state (device token, authoritative Client, server date, and clear generation) through `updateApplicationContext` whenever it changes. The clear generation counts clears; every local clear increments it and both devices keep the maximum they have seen. The receiver applies the incoming state as one external identity transition if `WatchSyncState.supersedes(_:from:)` says it wins:

1. Different clear generations: a state from the newer generation wins, so a clear on either device clears both. A state from before a clear can never undo it, whatever the device and server clocks say.
2. Same token or same Client ID: the devices share one server-side Client, so the newer snapshot wins (server date, then `Client.updatedAt`, then the phone's token when they differ). Signing in or out rotates the device token but keeps the Client.
3. Different tokens and Clients: a device without a token accepts any token, a signed-in Client beats a signed-out one, and otherwise the phone wins.

A receiver that rejects a state replies with its own state only when that state would win on the other device, so exchanges converge without loops. Adopting a token without a Client refreshes the Client from the server. Only the phone's environment is adopted. Payloads from earlier SDKs count as generation 0, and after upgrading, a clear recorded by SDK 1.5 on the phone starts the generation at 1.

## Clear And Reconfigure

`clearAllKeychainItems()` records the clear for Watch sync, deletes the identity record, signs out the in-memory Client, and deletes every other Clerk Keychain item except non-secret markers. With shared-session sync, the identity is shared, so a clear signs out every app sharing it.

Reconfiguration clears Clerk storage for the source and destination configurations without migrating the previous identity. An identity stored in an access group belongs to every app and extension in the group, so reconfiguration leaves it; a destination for another Clerk instance ignores it.

## Migration From Earlier Versions

`ClerkIdentityMigration` runs once per app and moves an existing identity into the record, preferring the SDK 1.5 atomic record over the earlier separate token, Client, and date items. Apps that adopted shared-session sync in SDK 1.5 skip the separate items, which that adoption left stale.

When another app already wrote the record, it is kept unless it is signed out and this app's identity is signed in. A clear made before the migration finished, including a shared-session clear interrupted in SDK 1.5, is honored by migrating nothing.

The migration then deletes every earlier copy, including this app's SDK 1.5 owner slot. Separate items in an access group are left for sibling apps still on an earlier SDK; a clear removes them. The migration is marked done only after every deletion succeeds, and not while the access group is unreachable, so it runs again on the next launch.

An app on SDK 1.5 and an app on this version do not see each other's shared sessions; update every app that shares an access group together.
