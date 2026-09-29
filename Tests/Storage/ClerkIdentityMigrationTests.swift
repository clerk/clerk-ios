@testable import ClerkKit
import Foundation
import Testing

struct ClerkIdentityMigrationTests {
  private let legacy = InMemoryKeychain()
  private let recordKeychain = InMemoryKeychain()

  private var store: ClerkIdentityStore {
    ClerkIdentityStore(keychain: recordKeychain, instanceFingerprint: "instance")
  }

  private var migration: ClerkIdentityMigration {
    ClerkIdentityMigration(store: store, legacyKeychain: legacy)
  }

  @Test
  func movesTheSeparateItemsIntoTheRecordAndRemovesThem() throws {
    try legacy.set("legacy-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try legacy.set(JSONEncoder.clerkEncoder.encode(Client.mock), forKey: ClerkKeychainKey.cachedClient.rawValue)
    try legacy.set("100", forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)
    try legacy.set("keep", forKey: ClerkKeychainKey.cachedEnvironment.rawValue)

    try migration.migrateIfNeeded()

    let identity = try #require(try store.load()?.identity)
    #expect(identity.deviceToken == "legacy-token")
    #expect(identity.client?.id == Client.mock.id)
    #expect(identity.serverDate == Date(timeIntervalSince1970: 100))
    for key in ClerkIdentityMigration.legacyIdentityKeys {
      #expect(try legacy.hasItem(forKey: key.rawValue) == false)
    }
    #expect(try legacy.string(forKey: ClerkKeychainKey.cachedEnvironment.rawValue) == "keep")
  }

  @Test
  func tokenWithAnUnreadableClientMovesAsTokenOnly() throws {
    try legacy.set("legacy-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try legacy.set(Data("not json".utf8), forKey: ClerkKeychainKey.cachedClient.rawValue)

    try migration.migrateIfNeeded()

    let identity = try #require(try store.load()?.identity)
    #expect(identity.state == .cleared)
    #expect(identity.deviceToken == "legacy-token")
    #expect(identity.client == nil)
  }

  @Test
  func keepsARecordAnotherAppAlreadyWrote() throws {
    try store.save(ClerkIdentitySnapshot(state: .present, deviceToken: "shared-token", client: .mock, serverDate: nil))
    try legacy.set("own-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)

    try migration.migrateIfNeeded()

    #expect(try store.load()?.identity.deviceToken == "shared-token")
    #expect(try legacy.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == false)
  }

  @Test
  func signedInIdentityReplacesASignedOutRecordAnotherAppWrote() throws {
    var signedOut = Client.mockSignedOut
    signedOut.id = "anonymous"
    try store.save(ClerkIdentitySnapshot(state: .present, deviceToken: "anonymous-token", client: signedOut, serverDate: nil))
    try legacy.set("signed-in-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try legacy.set(JSONEncoder.clerkEncoder.encode(Client.mock), forKey: ClerkKeychainKey.cachedClient.rawValue)

    try migration.migrateIfNeeded()

    #expect(try store.load()?.identity.deviceToken == "signed-in-token")
  }

  @Test
  func leavesTheRecordAloneWithoutSeparateItems() throws {
    let record = try #require(try store.save(ClerkIdentitySnapshot(state: .present, deviceToken: "token", client: .mock, serverDate: nil)))

    try migration.migrateIfNeeded()

    #expect(try store.load()?.revision == record.revision)
  }
}
