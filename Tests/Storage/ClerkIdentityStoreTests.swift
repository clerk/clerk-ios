@testable import ClerkKit
import Foundation
import Testing

struct ClerkIdentityStoreTests {
  @Test
  func phoneOrderingRemainsIndependentForAppsSharingAnIdentity() throws {
    let keychain = InMemoryKeychain()
    let first = ClerkIdentityStore(keychain: keychain, instanceFingerprint: "instance", watchSyncOwnerIdentifier: "app.a")
    let sibling = ClerkIdentityStore(keychain: keychain, instanceFingerprint: "instance", watchSyncOwnerIdentifier: "app.b")
    let identity = ClerkIdentitySnapshot(state: .present, deviceToken: "token", client: .mock, serverDate: nil)
    let modern = WatchSyncPhoneOrdering(usesCurrentSchema: true)
    let legacy = WatchSyncPhoneOrdering(version: .init(token: 2, auth: 3))
    let initial = try first.save(identity, replacing: nil, watchPhoneOrdering: modern)
    try sibling.save(identity, replacing: initial, watchPhoneOrdering: legacy)
    let record = try #require(try first.load())
    #expect(record.watchPhoneOrdering?["app.a"] == modern)
    #expect(record.watchPhoneOrdering?["app.b"] == legacy)
    #expect(record.epoch == initial.epoch)
    let cleared = try sibling.clear()
    #expect(cleared.watchPhoneOrdering == record.watchPhoneOrdering)
  }

  @Test
  func importedRecordsKeepIdentityAndWatchHistoryButRejectAStaleDestination() throws {
    let source = ClerkIdentityStore(keychain: InMemoryKeychain(), instanceFingerprint: "instance")
    let cleared = try source.clear()
    let signedIn = try source.save(
      .init(state: .present, deviceToken: "token", client: .mock, serverDate: Date(timeIntervalSince1970: 100)),
      replacing: cleared, watchClearGeneration: 7
    )
    let destination = ClerkIdentityStore(keychain: InMemoryKeychain(), instanceFingerprint: "instance")
    try destination.importRecord(signedIn, replacing: nil)
    let imported = try #require(try destination.load())

    #expect(imported.identity.deviceToken == "token")
    #expect(imported.identity.client?.id == signedIn.identity.client?.id)
    #expect(imported.identity.serverDate == signedIn.identity.serverDate)
    #expect(imported.revision != signedIn.revision)
    #expect(imported.epoch == signedIn.epoch)
    #expect(imported.clearEpoch == cleared.epoch)
    #expect(imported.watchClearGeneration == 7)
    #expect(imported.watchClearEpoch == cleared.epoch)
    #expect(throws: ClerkIdentityStoreError.writeConflict) { try destination.importRecord(cleared, replacing: nil) }
    #expect(try destination.load() == imported)
  }

  @Test
  func savesAndLoadsTheCompleteIdentityWithANewRevisionEachWrite() throws {
    let store = ClerkIdentityStore(keychain: InMemoryKeychain(), instanceFingerprint: "instance")
    let identity = ClerkIdentitySnapshot(
      state: .present,
      deviceToken: "token",
      client: .mock,
      serverDate: Date(timeIntervalSince1970: 100)
    )

    let first = try store.save(identity)
    let second = try store.save(identity)
    let loaded = try #require(try store.load())

    #expect(first.revision != second.revision)
    #expect(loaded.revision == second.revision)
    #expect(try store.revision() == second.revision)
    #expect(loaded.identity.deviceToken == "token")
    #expect(loaded.identity.client?.id == Client.mock.id)
    #expect(loaded.identity.serverDate == Date(timeIntervalSince1970: 100))
  }

  @Test
  func savingAnIdentityWithoutATokenRetainsACredentialFreeTombstone() throws {
    let store = ClerkIdentityStore(keychain: InMemoryKeychain(), instanceFingerprint: "instance")
    try store.save(ClerkIdentitySnapshot(state: .cleared, deviceToken: "token", client: nil, serverDate: nil))

    let cleared = try store.save(.signedOut)
    #expect(try store.load()?.identity == .signedOut)
    #expect(try store.revision() == cleared.revision)
  }

  @Test
  func recordsForDifferentInstancesDoNotOverwriteEachOther() throws {
    let keychain = InMemoryKeychain()
    let first = ClerkIdentityStore(keychain: keychain, instanceFingerprint: "first")
    let second = ClerkIdentityStore(keychain: keychain, instanceFingerprint: "second")
    try first.save(ClerkIdentitySnapshot(state: .cleared, deviceToken: "first-token", client: nil, serverDate: nil))

    #expect(try second.load() == nil)

    try second.save(ClerkIdentitySnapshot(state: .cleared, deviceToken: "second-token", client: nil, serverDate: nil))
    #expect(try second.load()?.identity.deviceToken == "second-token")
    #expect(try first.load()?.identity.deviceToken == "first-token")
  }

  @Test
  func unreadableClientKeepsTheDeviceToken() throws {
    let keychain = InMemoryKeychain()
    let store = ClerkIdentityStore(keychain: keychain, instanceFingerprint: "instance")
    try store.save(ClerkIdentitySnapshot(state: .present, deviceToken: "token", client: .mock, serverDate: nil))
    let data = try #require(try keychain.data(forKey: store.key))
    var json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    var identity = try #require(json["identity"] as? [String: Any])
    identity["client"] = ["unexpected": "shape"]
    json["identity"] = identity
    try keychain.set(JSONSerialization.data(withJSONObject: json), forKey: store.key)

    let loaded = try #require(try store.load()?.identity)

    #expect(loaded.deviceToken == "token")
    #expect(loaded.client == nil)
    #expect(loaded.state == .cleared)
  }

  @Test
  func rejectsARecordFromANewerSchema() throws {
    let keychain = InMemoryKeychain()
    let store = ClerkIdentityStore(keychain: keychain, instanceFingerprint: "instance")
    let record = ClerkIdentityStore.Record(
      schemaVersion: 99,
      revision: UUID(),
      instanceFingerprint: "instance",
      identity: ClerkIdentitySnapshot(state: .cleared, deviceToken: "token", client: nil, serverDate: nil)
    )
    try keychain.set(JSONEncoder.clerkEncoder.encode(record), forKey: store.key)

    #expect(throws: ClerkIdentityStoreError.unsupportedSchemaVersion(99)) {
      try store.load()
    }
  }

  @Test
  func rejectsAnInvalidIdentity() {
    let store = ClerkIdentityStore(keychain: InMemoryKeychain(), instanceFingerprint: "instance")

    #expect(throws: ClerkIdentitySnapshotError.invalidPresentState) {
      try store.save(ClerkIdentitySnapshot(state: .present, deviceToken: nil, client: .mock, serverDate: nil))
    }
  }

  @Test
  func crashAfterClearCommitDoesNotClearALaterLogin() throws {
    let keychain = InMemoryKeychain()
    let journal = FailingClearJournal()
    let store = ClerkIdentityStore(keychain: keychain, instanceFingerprint: "instance", clearIntentKeychain: journal)
    try store.save(ClerkIdentitySnapshot(state: .cleared, deviceToken: "old-token", client: nil, serverDate: nil))
    journal.failsDeletion = true
    #expect(throws: FailingClearJournal.Failure.self) { try store.clear() }
    #expect(try store.load()?.identity == .signedOut)
    try store.save(ClerkIdentitySnapshot(state: .cleared, deviceToken: "new-token", client: nil, serverDate: nil))
    journal.failsDeletion = false

    let reopened = ClerkIdentityStore(keychain: keychain, instanceFingerprint: "instance", clearIntentKeychain: journal)
    try reopened.recoverPendingClear()

    #expect(try reopened.load()?.identity.deviceToken == "new-token")
    #expect(try !journal.hasItem(forKey: reopened.clearIntentKey))
  }

  @Test
  func aDifferentStorageConfigurationCannotConsumeThePendingClear() throws {
    let journal = FailingClearJournal()
    let original = ClerkIdentityStore(
      keychain: InMemoryKeychain(), instanceFingerprint: "instance", clearIntentKeychain: journal, clearIntentScope: "original-group"
    )
    journal.failsDeletion = true
    #expect(throws: FailingClearJournal.Failure.self) { try original.clear() }
    journal.failsDeletion = false
    let destination = ClerkIdentityStore(
      keychain: InMemoryKeychain(), instanceFingerprint: "instance", clearIntentKeychain: journal, clearIntentScope: "new-group"
    )
    try destination.save(ClerkIdentitySnapshot(state: .cleared, deviceToken: "destination-token", client: nil, serverDate: nil))

    try destination.recoverPendingClear()

    #expect(try destination.load()?.identity.deviceToken == "destination-token")
    #expect(try journal.hasItem(forKey: original.clearIntentKey))
    try original.recoverPendingClear()
    #expect(try !journal.hasItem(forKey: original.clearIntentKey))
  }
}

private final class FailingClearJournal: KeychainStorage, @unchecked Sendable {
  enum Failure: Error { case deletion }
  let backing = InMemoryKeychain()
  var failsDeletion = false

  func set(_ data: Data, forKey key: String) throws {
    try backing.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    try backing.data(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try backing.hasItem(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    if failsDeletion { throw Failure.deletion }
    try backing.deleteItem(forKey: key)
  }
}
