@testable import ClerkKit
import Foundation
import Testing

struct SharedSessionLocalIdentityStoreTests {
  @Test
  func legacyIdentityBlobLoadsAsAcceptedRecord() throws {
    let keychain = InMemoryKeychain()
    let identity = makeIdentity(clientID: "legacy")
    try keychain.set(
      JSONEncoder.clerkEncoder.encode(identity),
      forKey: SharedSessionLocalIdentityStore.storageKey
    )

    let record = try #require(
      try SharedSessionLocalIdentityStore(keychain: keychain).loadRecord()
    )

    #expect(record.acceptedIdentity == identity)
    #expect(record.pendingPublication == nil)
  }

  @Test
  func stagingAndCommitReplaceOneAtomicRecord() throws {
    let store = SharedSessionLocalIdentityStore(keychain: InMemoryKeychain())
    let previous = makeIdentity(clientID: "previous")
    let pending = try makeEvent(clientID: "pending")
    let winner = makeIdentity(clientID: "winner")
    try store.save(previous)

    try store.stagePendingPublication(pending)

    let staged = try #require(try store.loadRecord())
    #expect(staged.acceptedIdentity == previous)
    #expect(staged.pendingPublication == pending)

    try store.commitAcceptedIdentity(
      winner,
      clearingPendingPublicationID: pending.id
    )

    let committed = try #require(try store.loadRecord())
    #expect(committed.acceptedIdentity == winner)
    #expect(committed.pendingPublication == nil)
  }

  @Test
  func mismatchedCommitCannotDiscardPendingPublication() throws {
    let store = SharedSessionLocalIdentityStore(keychain: InMemoryKeychain())
    let pending = try makeEvent(clientID: "pending")
    try store.stagePendingPublication(pending)

    #expect(throws: SharedSessionLocalIdentityStoreError.pendingPublicationMismatch) {
      try store.commitAcceptedIdentity(
        makeIdentity(clientID: "other"),
        clearingPendingPublicationID: UUID()
      )
    }

    #expect(try store.loadPendingPublication() == pending)
    #expect(try store.load() == nil)
  }

  @Test
  func synchronousInvalidatingDeleteRejectsOlderOperationSave() throws {
    let store = SharedSessionLocalIdentityStore(keychain: InMemoryKeychain())
    try store.save(makeIdentity(clientID: "initial"))

    try store.deleteInvalidatingOperations(through: 2)
    let didSaveOlderOperation = try store.save(
      makeIdentity(clientID: "older"),
      operationRevision: 1
    )
    let didSaveNewerOperation = try store.save(
      makeIdentity(clientID: "newer"),
      operationRevision: 3
    )

    #expect(didSaveOlderOperation == false)
    #expect(didSaveNewerOperation)
    #expect(try store.load()?.client?.id == "newer")
  }

  private func makeIdentity(clientID: String) -> SharedSessionLocalIdentity {
    var client = Client.mockSignedOut
    client.id = clientID
    return SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "token-\(clientID)",
      client: client,
      serverDate: nil
    )
  }

  private func makeEvent(clientID: String) throws -> SharedSessionIdentityEvent {
    let identity = makeIdentity(clientID: clientID)
    return try SharedSessionIdentityEvent(
      id: UUID(),
      originOwnerIdentifier: "app.a",
      generation: 1,
      state: identity.state,
      deviceToken: identity.deviceToken,
      client: identity.client,
      serverDate: identity.serverDate
    ).validated()
  }
}
