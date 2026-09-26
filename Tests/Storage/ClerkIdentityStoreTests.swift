@testable import ClerkKit
import Foundation
import Testing

struct ClerkIdentityStoreTests {
  @Test
  func savesAndLoadsTheCompleteIdentityWithANewRevisionEachWrite() throws {
    let store = ClerkIdentityStore(keychain: InMemoryKeychain(), instanceFingerprint: "instance")
    let identity = ClerkIdentitySnapshot(
      state: .present,
      deviceToken: "token",
      client: .mock,
      serverDate: Date(timeIntervalSince1970: 100)
    )

    let first = try #require(try store.save(identity))
    let second = try #require(try store.save(identity))
    let loaded = try #require(try store.load())

    #expect(first.revision != second.revision)
    #expect(loaded.revision == second.revision)
    #expect(try store.revision() == second.revision)
    #expect(loaded.identity.deviceToken == "token")
    #expect(loaded.identity.client?.id == Client.mock.id)
    #expect(loaded.identity.serverDate == Date(timeIntervalSince1970: 100))
  }

  @Test
  func savingAnIdentityWithoutATokenDeletesTheRecord() throws {
    let store = ClerkIdentityStore(keychain: InMemoryKeychain(), instanceFingerprint: "instance")
    try store.save(ClerkIdentitySnapshot(state: .cleared, deviceToken: "token", client: nil, serverDate: nil))

    #expect(try store.save(.signedOut) == nil)
    #expect(try store.load() == nil)
    #expect(try store.revision() == nil)
  }

  @Test
  func recordForAnotherInstanceIsIgnoredAndReplaced() throws {
    let keychain = InMemoryKeychain()
    let first = ClerkIdentityStore(keychain: keychain, instanceFingerprint: "first")
    let second = ClerkIdentityStore(keychain: keychain, instanceFingerprint: "second")
    try first.save(ClerkIdentitySnapshot(state: .cleared, deviceToken: "first-token", client: nil, serverDate: nil))

    #expect(throws: ClerkIdentityStoreError.otherInstance) {
      try second.load()
    }

    try second.save(ClerkIdentitySnapshot(state: .cleared, deviceToken: "second-token", client: nil, serverDate: nil))
    #expect(try second.load()?.identity.deviceToken == "second-token")
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
}
