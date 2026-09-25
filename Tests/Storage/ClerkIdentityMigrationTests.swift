@testable import ClerkKit
import Foundation
import Testing

struct ClerkIdentityMigrationTests {
  private let fingerprint = "instance"
  private let owner = "com.example.app"
  private let service = "com.example.app"
  private let accessGroup = "TEAMID.shared"

  @Test
  func migratesTheSeparateLegacyItemsAndRemovesThem() throws {
    let env = Environment(accessGroup: nil)
    try env.legacy.set("legacy-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try env.legacy.set(JSONEncoder.clerkEncoder.encode(Client.mock), forKey: ClerkKeychainKey.cachedClient.rawValue)
    try env.legacy.set("100", forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)
    try env.legacy.set("keep", forKey: ClerkKeychainKey.cachedEnvironment.rawValue)

    try migration(env).migrateIfNeeded()

    let identity = try #require(try env.store.load()?.identity)
    #expect(identity.deviceToken == "legacy-token")
    #expect(identity.client?.id == Client.mock.id)
    #expect(identity.serverDate == Date(timeIntervalSince1970: 100))
    for key in ClerkIdentityMigration.legacyIdentityKeys {
      #expect(try env.legacy.hasItem(forKey: key.rawValue) == false)
    }
    #expect(try env.legacy.string(forKey: ClerkKeychainKey.cachedEnvironment.rawValue) == "keep")
  }

  @Test
  func legacyTokenWithAnUnreadableClientMigratesAsTokenOnly() throws {
    let env = Environment()
    try env.legacy.set("legacy-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try env.legacy.set(Data("not json".utf8), forKey: ClerkKeychainKey.cachedClient.rawValue)

    try migration(env).migrateIfNeeded()

    let identity = try #require(try env.store.load()?.identity)
    #expect(identity.state == .cleared)
    #expect(identity.deviceToken == "legacy-token")
    #expect(identity.client == nil)
  }

  @Test
  func prefersTheAtomicRecordFromSharedSessionSyncAndRemovesItsCopies() throws {
    let env = Environment()
    try env.legacy.set("older-legacy-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try env.keychain(stableService).set(atomicRecord(token: "atomic-token"), forKey: "clerkSharedSessionLocalIdentityV2")
    try env.keychain(slotService, accessGroup).set(Data("slot".utf8), forKey: slotAccount)

    try migration(env).migrateIfNeeded()

    #expect(try env.store.load()?.identity.deviceToken == "atomic-token")
    #expect(try env.keychain(stableService).hasItem(forKey: "clerkSharedSessionLocalIdentityV2") == false)
    #expect(try env.keychain(slotService, accessGroup).hasItem(forKey: slotAccount) == false)
    // Separate items in an access group stay for sibling apps on an earlier SDK.
    #expect(try env.legacy.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue))
  }

  @Test
  func interruptedClearFromSharedSessionSyncIsHonored() throws {
    let env = Environment()
    try env.keychain(stableService).set(atomicRecord(token: "cleared-token"), forKey: "clerkSharedSessionLocalIdentityV2")
    let intent = try JSONEncoder.clerkEncoder.encode([
      "schemaVersion": "1",
      "localIdentityService": stableService,
      "slotService": slotService,
      "slotAccessGroup": accessGroup,
      "slotAccount": slotAccount,
      "instanceFingerprint": fingerprint,
      "ownerIdentifier": owner,
    ])
    try env.keychain(journalService).set(intent, forKey: "clerkSharedSessionOwnerSlotClearIntentV1")

    try migration(env).migrateIfNeeded()

    #expect(try env.store.load() == nil)
    #expect(try env.keychain(stableService).hasItem(forKey: "clerkSharedSessionLocalIdentityV2") == false)
    #expect(try env.keychain(journalService).hasItem(forKey: "clerkSharedSessionOwnerSlotClearIntentV1") == false)
  }

  @Test
  func keepsARecordAnotherAppAlreadyWrote() throws {
    let env = Environment()
    try env.store.save(ClerkIdentitySnapshot(state: .present, deviceToken: "shared-token", client: .mock, serverDate: nil))
    try env.keychain(stableService).set(atomicRecord(token: "own-token"), forKey: "clerkSharedSessionLocalIdentityV2")

    try migration(env).migrateIfNeeded()

    #expect(try env.store.load()?.identity.deviceToken == "shared-token")
    #expect(try env.keychain(stableService).hasItem(forKey: "clerkSharedSessionLocalIdentityV2") == false)
  }

  @Test
  func signedInIdentityReplacesASignedOutRecordAnotherAppWrote() throws {
    let env = Environment()
    var signedOut = Client.mockSignedOut
    signedOut.id = "anonymous"
    try env.store.save(ClerkIdentitySnapshot(state: .present, deviceToken: "anonymous-token", client: signedOut, serverDate: nil))
    try env.keychain(stableService).set(atomicRecord(token: "signed-in-token"), forKey: "clerkSharedSessionLocalIdentityV2")

    try migration(env).migrateIfNeeded()

    #expect(try env.store.load()?.identity.deviceToken == "signed-in-token")
  }

  @Test
  func appsThatAdoptedSyncIgnoreStaleSeparateItems() throws {
    let env = Environment()
    try env.legacy.set("stale-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    var migration = migration(env)
    migration.readsLegacyItems = false

    try migration.migrateIfNeeded()

    #expect(try env.store.load() == nil)
  }

  @Test
  func failedCleanupIsRetriedOnTheNextLaunch() throws {
    let env = Environment(accessGroup: nil)
    let failingLegacy = DeleteFailingKeychain()
    try failingLegacy.set("legacy-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    var migration = ClerkIdentityMigration(
      store: ClerkIdentityStore(keychain: env.legacy, instanceFingerprint: fingerprint),
      legacyKeychain: failingLegacy,
      markerKeychain: env.marker,
      configuredService: service,
      accessGroup: nil,
      ownerIdentifier: owner,
      instanceFingerprint: fingerprint
    )
    migration.makeKeychain = { env.keychain($0, $1) }

    try migration.migrateIfNeeded()

    #expect(try env.store.load()?.identity.deviceToken == "legacy-token")
    #expect(try env.marker.string(forKey: ClerkKeychainKey.identityMigrated.rawValue) == nil)
  }

  @Test
  func unreachableAccessGroupCopiesTheIdentityWithoutFinishing() throws {
    let env = Environment()
    try env.keychain(stableService).set(atomicRecord(token: "atomic-token"), forKey: "clerkSharedSessionLocalIdentityV2")
    var migration = migration(env)
    migration.finalizes = false

    try migration.migrateIfNeeded()

    #expect(try env.store.load()?.identity.deviceToken == "atomic-token")
    #expect(try env.keychain(stableService).hasItem(forKey: "clerkSharedSessionLocalIdentityV2"))
    #expect(try env.marker.string(forKey: ClerkKeychainKey.identityMigrated.rawValue) == nil)
  }

  @Test
  func runsOncePerApp() throws {
    let env = Environment()
    try migration(env).migrateIfNeeded()
    try env.legacy.set("later-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)

    try migration(env).migrateIfNeeded()

    #expect(try env.store.load() == nil)
    #expect(try env.marker.string(forKey: ClerkKeychainKey.identityMigrated.rawValue) == ClerkIdentityMigration.markerValue)
  }

  @Test
  func privateStateMovesOutOfTheSharedGroupWhenSyncIsFirstEnabled() throws {
    let shared = InMemoryKeychain()
    let appLocal = InMemoryKeychain()
    let marker = InMemoryKeychain()
    try shared.set(JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock), forKey: ClerkKeychainKey.cachedEnvironment.rawValue)
    try shared.set("attest-key", forKey: ClerkKeychainKey.attestKeyId.rawValue)

    try AppLocalStateAdoption(markerKeychain: marker, appLocal: appLocal, shared: shared).adoptIfNeeded()

    #expect(try appLocal.hasItem(forKey: ClerkKeychainKey.cachedEnvironment.rawValue))
    #expect(try appLocal.string(forKey: ClerkKeychainKey.attestKeyId.rawValue) == "attest-key")
    #expect(try AppLocalStateAdoption.isAdopted(in: marker))
  }

  // MARK: - Helpers

  private var stableService: String {
    "\(owner).clerk.identity.v2.\(fingerprint)"
  }

  private var journalService: String {
    "\(owner).clerk.shared-session-clear-recovery.v1"
  }

  private var slotService: String {
    "\(service).\(SharedSessionNamespace.protocolIdentifier).\(fingerprint)"
  }

  private var slotAccount: String {
    let seed = "\(SharedSessionNamespace.protocolIdentifier)\u{1F}\(fingerprint)\u{1F}\(owner)"
    return "owner.\(SharedSessionNamespace.sha256(seed))"
  }

  private func atomicRecord(token: String) throws -> Data {
    struct Record: Encodable {
      let schemaVersion = 1
      let acceptedIdentity: ClerkIdentitySnapshot
      let requiresLegacyAdoptionPublication = false
    }
    return try JSONEncoder.clerkEncoder.encode(Record(acceptedIdentity: ClerkIdentitySnapshot(
      state: .present,
      deviceToken: token,
      client: .mock,
      serverDate: Date(timeIntervalSince1970: 100)
    )))
  }

  private func migration(_ env: Environment) -> ClerkIdentityMigration {
    var migration = ClerkIdentityMigration(
      store: env.store,
      legacyKeychain: env.legacy,
      markerKeychain: env.marker,
      configuredService: service,
      accessGroup: env.accessGroup,
      ownerIdentifier: owner,
      instanceFingerprint: fingerprint
    )
    migration.makeKeychain = { env.keychain($0, $1) }
    return migration
  }

  /// Keychains keyed by service and access group, like the system Keychain.
  private final class Environment: @unchecked Sendable {
    let accessGroup: String?
    let legacy = InMemoryKeychain()
    let marker = InMemoryKeychain()
    private var keychains: [String: InMemoryKeychain] = [:]
    private let lock = NSLock()

    init(accessGroup: String? = "TEAMID.shared") {
      self.accessGroup = accessGroup
    }

    var store: ClerkIdentityStore {
      ClerkIdentityStore(keychain: legacy, instanceFingerprint: "instance")
    }

    func keychain(_ service: String, _ accessGroup: String? = nil) -> InMemoryKeychain {
      lock.withLock {
        let id = "\(service)|\(accessGroup ?? "")"
        if let keychain = keychains[id] { return keychain }
        let keychain = InMemoryKeychain()
        keychains[id] = keychain
        return keychain
      }
    }
  }
}

private final class DeleteFailingKeychain: @unchecked Sendable, KeychainStorage {
  private let backing = InMemoryKeychain()

  func set(_ data: Data, forKey key: String) throws {
    try backing.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    try backing.data(forKey: key)
  }

  func deleteItem(forKey _: String) throws {
    throw KeychainError.unexpectedStatus(errSecInteractionNotAllowed)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try backing.hasItem(forKey: key)
  }
}
