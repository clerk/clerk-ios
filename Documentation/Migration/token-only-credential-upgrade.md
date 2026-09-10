# Token-only credential upgrade

The previous native majors can retain a usable device credential without a cached client. Startup must send that credential to the canonical TypeScript client refresh before exposing session state. Treating an absent client projection as deletion of the credential caused the new importers to persist an empty record and unnecessarily discard the credential.

## Source evidence

The reviewed iOS baseline is `02f98f89a19b6c079517c9aae07df7edd0e600e5`:

- `Sources/ClerkKit/Identity/ClerkIdentitySnapshot.swift` validates `state: cleared` with a nonempty token and no client.
- `Sources/ClerkKit/SharedSessionSync/SharedSessionSyncAdoption.swift` deliberately imports legacy credentials in that form. Its `loadCoherentIdentity` comment explains that independently persisted client/date items cannot establish one revision, so only the credential is retained for canonical refresh.
- `Sources/ClerkKit/Identity/ClerkIdentityController.swift` hydrates the device token independently of the client and uses a cleared, token-only identity when replacing a device token.

The reviewed Android baseline is `1ea9f97250e9e3b266b7fbcfe37d9373e4fc393f`:

- `source/api/src/main/kotlin/com/clerk/api/sharedsession/SharedSessionSyncSnapshot.kt` stores client/auth and device-token snapshots separately.
- `SharedSessionSyncCoordinator.handleClientChange` changes the auth projection; `handleDeviceTokenChange` changes the device-token record. `applyDeviceTokenSnapshot` persists a set token independently of the auth projection.
- `Clerk.getDeviceToken` reads the device credential and `refreshClient` reconciles through the server. A cleared auth projection does not itself delete the credential; reset explicitly deletes device-token storage.

## Current import rules

On Apple platforms, a scoped accepted identity can provide a credential when it is either present with a client object or cleared with no client. Both require a nonempty token. If a pending publication exists, it must also contain a coherent identity with the same credential. An absent/empty/conflicting pending credential is not adopted. The old publication marker does not cause this SDK to resume shared-session synchronization.

A matching interrupted-clear journal still suppresses import, including for token-only identities. Invalid journals throw. A new durable empty record takes precedence over all prior records. Missing/invalid accepted identities never fall back to an older unscoped token from another record. Unscoped token import continues to require an explicit matching publishable key.

On Android, matching instance/schema checks remain. A set device-token record supplies the credential even when the separate auth/client projection is cleared. An explicit cleared device-token record blocks import and fallback. A new encrypted empty record remains authoritative after reopening. The migration does not use the old cached client as authenticated state.

These are credential-recovery rules, not native session-selection logic. The existing shared core performs startup HTTP and validates the server response; importing a token does not claim that the user is signed in. No shared-session convergence or offline resource bootstrap is introduced.

## Verification and limits

The Apple token-only test first failed for all four prior-format cases: unversioned identity, settled versioned record, required-publication record, and matching pending publication. The Android cleared-client/set-device-token test also failed before the fix.

After the fix, the complete Apple credential-storage suite passes on macOS and iOS Simulator. It checks all four recoverable records, six invalid/conflicting token-only records, matching versus other-instance interrupted clears for present and token-only identities, current-record precedence, durable clears, OS read/write failures, and scoped imports. The Android credential-upgrade suite passes on the emulator using encrypted legacy preferences, Android Keystore and the current encrypted file. It includes the new independent-token case and the existing explicit-clear/reopen case.

The Apple separate-process proof now seeds both present and token-only prior identities in isolated UUID Keychain namespaces. Repeated restore, clear and cleared-state verification pass. The packaged-core smoke proof also passes. These fixtures do not establish a released-app upgrade with a real signed-in account, physical-device entitlements, or concurrent shared-app behavior; those remain release gates.
