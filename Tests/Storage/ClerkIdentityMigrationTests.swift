@testable import ClerkKit
import Foundation
import Testing

struct ClerkIdentityMigrationTests {
  private let fingerprint = "instance"
  private let owner = "com.example.app"
  private let service = "com.example.app"
  private let accessGroup = "TEAMID.shared"

  @Test
  func migratesOnlyTheTokenAndPreservesAmbiguousLegacyItems() throws {
    let env = Environment(accessGroup: nil)
    try env.legacy.set("legacy-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try env.legacy.set(JSONEncoder.clerkEncoder.encode(Client.mock), forKey: ClerkKeychainKey.cachedClient.rawValue)
    try env.legacy.set("100", forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)
    try env.legacy.set("keep", forKey: ClerkKeychainKey.cachedEnvironment.rawValue)

    try migration(env).migrateIfNeeded()

    let identity = try #require(try env.store.load()?.identity)
    #expect(identity.deviceToken == "legacy-token")
    // These fields were written independently; their apparent validity cannot prove
    // that the cached Client belongs to this token. A refresh establishes that pair.
    #expect(identity.client == nil)
    #expect(identity.serverDate == nil)
    for key in ClerkIdentityMigration.legacyIdentityKeys {
      #expect(try env.legacy.hasItem(forKey: key.rawValue) == [.clerkDeviceToken, .cachedClient, .cachedClientServerDate].contains(key))
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

  @Test(arguments: [false, true])
  func prefersTheAtomicRecordFromSharedSessionSyncAndRemovesItsCopies(hasPublication: Bool) throws {
    let env = Environment()
    try env.legacy.set("older-legacy-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try env.keychain(stableService).set(atomicRecord(token: "atomic-token"), forKey: "clerkSharedSessionLocalIdentityV2")
    if hasPublication {
      try saveSlot(in: env, owner: owner, identity: .init(
        state: .present, deviceToken: "atomic-token", client: .mock, serverDate: Date(timeIntervalSince1970: 100)
      ), generation: 1)
    }

    try migration(env).migrateIfNeeded()

    #expect(try env.store.load()?.identity.deviceToken == "atomic-token")
    #expect(try env.store.load()?.identity.client?.id == Client.mock.id)
    #expect(try env.store.load()?.identity.serverDate == Date(timeIntervalSince1970: 100))
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

    #expect(try env.store.load()?.identity == .signedOut)
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
  func legacyIdentityCannotReplaceASignedOutRecordAnotherAppWrote() throws {
    let env = Environment()
    var signedOut = Client.mockSignedOut
    signedOut.id = "anonymous"
    try env.store.save(ClerkIdentitySnapshot(state: .present, deviceToken: "anonymous-token", client: signedOut, serverDate: nil))
    try env.keychain(stableService).set(atomicRecord(token: "signed-in-token"), forKey: "clerkSharedSessionLocalIdentityV2")

    try migration(env).migrateIfNeeded()

    #expect(try env.store.load()?.identity.deviceToken == "anonymous-token")
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
    let env = Environment()
    let atomic = env.keychain(stableService)
    try atomic.set(atomicRecord(token: "atomic-token"), forKey: "clerkSharedSessionLocalIdentityV2")
    let service = stableService
    var firstAttempt = migration(env)
    firstAttempt.makeKeychain = { name, group in
      if name == service { return DeleteFailingKeychain(backing: atomic) }
      return env.keychain(name, group)
    }

    try firstAttempt.migrateIfNeeded()

    #expect(try env.store.load()?.identity.deviceToken == "atomic-token")
    #expect(try env.marker.string(forKey: migration(env).markerKey) == nil)
    #expect(try atomic.hasItem(forKey: "clerkSharedSessionLocalIdentityV2"))

    try migration(env).migrateIfNeeded()
    #expect(try !atomic.hasItem(forKey: "clerkSharedSessionLocalIdentityV2"))
    #expect(try env.marker.string(forKey: migration(env).markerKey) == ClerkIdentityMigration.markerValue)
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
    #expect(try env.marker.string(forKey: migration.markerKey) == nil)
  }

  @Test
  func runsOncePerApp() throws {
    let env = Environment()
    try migration(env).migrateIfNeeded()
    try env.legacy.set("later-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)

    try migration(env).migrateIfNeeded()

    #expect(try env.store.load() == nil)
    #expect(try env.marker.string(forKey: migration(env).markerKey) == ClerkIdentityMigration.markerValue)
  }

  @Test
  func privateStateIsNotImportedFromAnAmbiguousSharedGroup() throws {
    let shared = InMemoryKeychain()
    let appLocal = InMemoryKeychain()
    let marker = InMemoryKeychain()
    try shared.set(JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock), forKey: ClerkKeychainKey.cachedEnvironment.rawValue)
    try shared.set("attest-key", forKey: ClerkKeychainKey.attestKeyId.rawValue)

    try AppLocalStateAdoption(markerKeychain: marker, appLocal: appLocal, shared: shared).adoptIfNeeded()

    #expect(try appLocal.hasItem(forKey: ClerkKeychainKey.cachedEnvironment.rawValue))
    #expect(try appLocal.string(forKey: ClerkKeychainKey.attestKeyId.rawValue) == nil)
    #expect(try AppLocalStateAdoption.usesAppLocalStorage(in: marker))
  }

  // MARK: - Helpers

  @Test
  func laterMigrationCannotResurrectAClearedIdentity() throws {
    let env = Environment()
    let cleared = try env.store.clear()
    try env.keychain(stableService).set(atomicRecord(token: "old-token"), forKey: "clerkSharedSessionLocalIdentityV2")
    try migration(env).migrateIfNeeded()
    #expect(try env.store.load() == cleared)
  }

  @Test
  func firstUpgradingAppUsesTheSiblingsPublishedLoginWithoutItsOwnLegacyIdentity() throws {
    let env = Environment()
    let identity = ClerkIdentitySnapshot(state: .present, deviceToken: "sibling-token", client: .mock, serverDate: nil)
    let siblingAccount = try saveSlot(in: env, owner: "sibling", identity: identity, generation: 3)

    try migration(env).migrateIfNeeded()

    let migrated = try #require(try env.store.load()?.identity)
    #expect(migrated.deviceToken == identity.deviceToken)
    #expect(migrated.client?.id == identity.client?.id)
    #expect(migrated.client?.sessions.map(\.id) == identity.client?.sessions.map(\.id))
    // A migrating app removes only its own old publication, never a sibling's.
    #expect(try env.keychain(slotService, accessGroup).hasItem(forKey: siblingAccount))
  }

  @Test(arguments: [false, true])
  func aNewerPublishedSignOutBeatsAnOldLocalLogin(cleared: Bool) throws {
    let env = Environment()
    try env.keychain(stableService).set(atomicRecord(token: "old-token"), forKey: "clerkSharedSessionLocalIdentityV2")
    try saveSlot(in: env, owner: owner, identity: .init(
      state: .present, deviceToken: "old-token", client: .mock, serverDate: nil
    ), generation: 1)
    let latest: ClerkIdentitySnapshot = cleared ? .signedOut : .init(
      state: .present, deviceToken: "old-token", client: .mockSignedOut, serverDate: nil
    )
    try saveSlot(in: env, owner: "sibling", identity: latest, generation: 2)

    try migration(env).migrateIfNeeded()

    #expect(try env.store.load()?.identity == latest)
  }

  @Test
  func aNewerPublishedLoginBeatsThisAppsSignedOutLocalSnapshot() throws {
    let env = Environment()
    try env.keychain(stableService).set(JSONEncoder.clerkEncoder.encode(ClerkIdentitySnapshot.signedOut),
                                        forKey: "clerkSharedSessionLocalIdentityV2")
    try saveSlot(in: env, owner: owner, identity: .signedOut, generation: 1)
    let latest = ClerkIdentitySnapshot(state: .present, deviceToken: "new-token", client: .mock, serverDate: nil)
    try saveSlot(in: env, owner: "sibling", identity: latest, generation: 2)

    try migration(env).migrateIfNeeded()

    let migrated = try #require(try env.store.load()?.identity)
    #expect(migrated.deviceToken == latest.deviceToken)
    #expect(migrated.client?.id == latest.client?.id)
    #expect(migrated.client?.sessions.map(\.id) == latest.client?.sessions.map(\.id))
  }

  @Test
  func aPendingPublicationCompetesWithAllSiblingsUsingTheOldOrdering() throws {
    let env = Environment()
    var record = try #require(JSONSerialization.jsonObject(with: atomicRecord(token: "previous")) as? [String: Any])
    record["pending_publication"] = try publication(token: "staged", generation: 3)
    try env.keychain(stableService).set(JSONSerialization.data(withJSONObject: record), forKey: "clerkSharedSessionLocalIdentityV2")
    try saveSlot(in: env, owner: "sibling", identity: .signedOut, generation: 2)

    try migration(env).migrateIfNeeded()

    #expect(try env.store.load()?.identity.deviceToken == "staged")
  }

  @Test
  func aNewGroupIdentityStillWinsOverLaterLegacyPublications() throws {
    let env = Environment()
    let current = try env.store.save(.signedOut)
    try saveSlot(in: env, owner: "sibling", identity: .init(
      state: .present, deviceToken: "stale-token", client: .mock, serverDate: nil
    ), generation: 99)

    try migration(env).migrateIfNeeded()

    #expect(try env.store.load() == current)
  }

  @Test
  func anAppLocalIdentityDoesNotAdoptSiblingSlots() throws {
    let env = Environment()
    try env.keychain(stableService).set(atomicRecord(token: "local-token"), forKey: "clerkSharedSessionLocalIdentityV2")
    try saveSlot(in: env, owner: "sibling", identity: .signedOut, generation: 9)
    var migration = migration(env)
    migration.readsSharedSlots = false

    try migration.migrateIfNeeded()

    #expect(try env.store.load()?.identity.deviceToken == "local-token")
  }

  @Test
  func anUnavailableSlotReadDefersMigrationWithoutDeletingTheLocalLogin() throws {
    let env = Environment()
    try env.keychain(stableService).set(atomicRecord(token: "local-token"), forKey: "clerkSharedSessionLocalIdentityV2")
    let failing = MigrationReadFailingKeychain()
    let slots = slotService
    var firstAttempt = migration(env)
    firstAttempt.makeKeychain = { service, group in
      if service == slots { return failing }
      return env.keychain(service, group)
    }

    #expect(throws: (any Error).self) { try firstAttempt.migrateIfNeeded() }
    #expect(try env.store.load() == nil)
    #expect(try env.keychain(stableService).hasItem(forKey: "clerkSharedSessionLocalIdentityV2"))
    #expect(try env.marker.data(forKey: migration(env).markerKey) == nil)

    try migration(env).migrateIfNeeded()
    #expect(try env.store.load()?.identity.deviceToken == "local-token")
  }

  @Test(arguments: [0, 1, 2, 3])
  func publishedWinnerUsesGenerationThenDateThenOwnerThenEventID(orderingField: Int) throws {
    let env = Environment()
    let left = ClerkIdentitySnapshot(
      state: .present, deviceToken: "left", client: .mock,
      serverDate: orderingField == 1 ? nil : Date(timeIntervalSince1970: 200)
    )
    let right = ClerkIdentitySnapshot(
      state: .present, deviceToken: "right", client: .mockSignedOut,
      serverDate: Date(timeIntervalSince1970: orderingField < 2 ? 100 : 200)
    )
    try saveSlot(in: env, owner: "peer-a", identity: left, generation: 1,
                 eventID: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001")),
                 origin: orderingField == 2 ? "a" : "same")
    try saveSlot(in: env, owner: "peer-b", identity: right, generation: orderingField == 0 ? 2 : 1,
                 eventID: #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002")),
                 origin: orderingField == 2 ? "z" : "same")

    try migration(env).migrateIfNeeded()

    #expect(try env.store.load()?.identity == right)
  }

  @Test
  func conflictingReplicasStopMigrationWithoutDeletingTheSources() throws {
    let env = Environment()
    let id = UUID()
    let first = try saveSlot(in: env, owner: owner, identity: .signedOut, generation: 2, eventID: id, origin: owner)
    try saveSlot(in: env, owner: "sibling", identity: .init(
      state: .present, deviceToken: "conflicting-token", client: .mock, serverDate: nil
    ), generation: 2, eventID: id, origin: owner)

    #expect(throws: ClerkIdentityMigrationError.self) { try migration(env).migrateIfNeeded() }

    #expect(try env.store.load() == nil)
    #expect(try env.keychain(slotService, accessGroup).hasItem(forKey: first))
    #expect(try env.marker.data(forKey: migration(env).markerKey) == nil)
  }

  @discardableResult
  private func saveSlot(
    in env: Environment, owner: String, identity: ClerkIdentitySnapshot, generation: Int,
    eventID: UUID = UUID(), origin: String? = nil
  ) throws -> String {
    var event = try #require(JSONSerialization.jsonObject(with: JSONEncoder.clerkEncoder.encode(identity)) as? [String: Any])
    event["id"] = eventID.uuidString
    event["origin_owner_identifier"] = origin ?? owner
    event["generation"] = generation
    let slot: [String: Any] = [
      "schema_version": 2, "instance_fingerprint": fingerprint, "slot_owner_identifier": owner, "event": event,
    ]
    let seed = "\(SharedSessionNamespace.protocolIdentifier)\u{1F}\(fingerprint)\u{1F}\(owner)"
    let account = "owner.\(SharedSessionNamespace.sha256(seed))"
    try env.keychain(slotService, accessGroup).set(JSONSerialization.data(withJSONObject: slot), forKey: account)
    return account
  }

  @Test(arguments: [false, true])
  func interruptedPublicationMigratesItsStagedIdentity(cleared: Bool) throws {
    let env = Environment()
    var record = try #require(JSONSerialization.jsonObject(with: atomicRecord(token: "previous")) as? [String: Any])
    record["pending_publication"] = try publication(token: cleared ? nil : "staged", generation: 2)
    try env.keychain(stableService).set(JSONSerialization.data(withJSONObject: record), forKey: "clerkSharedSessionLocalIdentityV2")

    try migration(env).migrateIfNeeded()

    #expect(try env.store.load()?.identity.deviceToken == (cleared ? nil : "staged"))
    #expect(try env.keychain(stableService).data(forKey: "clerkSharedSessionLocalIdentityV2") == nil)
  }

  @Test
  func interruptedPublicationDoesNotReplaceANewerPublishedWinner() throws {
    let env = Environment()
    var record = try #require(JSONSerialization.jsonObject(with: atomicRecord(token: "previous")) as? [String: Any])
    record["pending_publication"] = try publication(token: "staged", generation: 2)
    try env.keychain(stableService).set(JSONSerialization.data(withJSONObject: record), forKey: "clerkSharedSessionLocalIdentityV2")
    let slot: [String: Any] = try [
      "schema_version": 2, "instance_fingerprint": fingerprint, "slot_owner_identifier": owner,
      "event": publication(token: nil, generation: 3),
    ]
    try env.keychain(slotService, accessGroup).set(JSONSerialization.data(withJSONObject: slot), forKey: slotAccount)

    try migration(env).migrateIfNeeded()

    #expect(try env.store.load()?.identity == .signedOut)
  }

  @Test
  func publicationFromAnotherOwnerStopsMigrationAndKeepsItsSource() throws {
    let env = Environment()
    var record = try #require(JSONSerialization.jsonObject(with: atomicRecord(token: "previous")) as? [String: Any])
    var pending = try publication(token: "staged", generation: 2)
    pending["origin_owner_identifier"] = "other-app"
    record["pending_publication"] = pending
    try env.keychain(stableService).set(JSONSerialization.data(withJSONObject: record), forKey: "clerkSharedSessionLocalIdentityV2")

    #expect(throws: ClerkIdentityMigrationError.self) { try migration(env).migrateIfNeeded() }

    #expect(try env.store.load() == nil)
    #expect(try env.keychain(stableService).hasItem(forKey: "clerkSharedSessionLocalIdentityV2"))
    #expect(try env.marker.data(forKey: migration(env).markerKey) == nil)
  }

  @Test
  func migratesTheOlderUnwrappedAtomicSnapshot() throws {
    let env = Environment()
    let snapshot = ClerkIdentitySnapshot(state: .cleared, deviceToken: "early-token", client: nil, serverDate: nil)
    try env.keychain(stableService).set(JSONEncoder.clerkEncoder.encode(snapshot), forKey: "clerkSharedSessionLocalIdentityV2")

    try migration(env).migrateIfNeeded()

    #expect(try env.store.load()?.identity == snapshot)
  }

  private func publication(token: String?, generation: Int) throws -> [String: Any] {
    let identity = ClerkIdentitySnapshot(state: .cleared, deviceToken: token, client: nil, serverDate: nil)
    var event = try #require(JSONSerialization.jsonObject(with: JSONEncoder.clerkEncoder.encode(identity)) as? [String: Any])
    event["id"] = UUID().uuidString
    event["origin_owner_identifier"] = owner
    event["generation"] = generation
    return event
  }

  @Test
  func enablingSharingMigratesTheExistingAppLocalLoginFirst() throws {
    let env = Environment()
    try env.marker.set("local-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try env.legacy.set("shared-legacy-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try migration(env).migrateIfNeeded()
    #expect(try env.store.load()?.identity.deviceToken == "local-token")
  }

  @Test
  func unavailableSharedGroupStillAllowsAppLocalLegacyRecovery() throws {
    let env = Environment()
    try env.marker.set("local-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    var migration = migration(env)
    migration.readsSharedLegacyItems = false
    migration.finalizes = false

    try migration.migrateIfNeeded()

    #expect(try env.store.load()?.identity.deviceToken == "local-token")
    #expect(try env.marker.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "local-token")
    #expect(try env.marker.data(forKey: migration.markerKey) == nil)
  }

  @Test
  func failedLegacyCleanupKeepsClearIntentUntilTheRetrySucceeds() throws {
    let env = Environment()
    try env.keychain(stableService).set(atomicRecord(token: "old-token"), forKey: "clerkSharedSessionLocalIdentityV2")
    let journal = env.keychain(journalService)
    try journal.set(JSONEncoder.clerkEncoder.encode([
      "localIdentityService": stableService, "slotService": slotService,
      "slotAccessGroup": accessGroup, "slotAccount": slotAccount,
    ]), forKey: "clerkSharedSessionOwnerSlotClearIntentV1")
    var firstAttempt = migration(env)
    let failing = DeleteFailingKeychain(backing: env.keychain(stableService))
    let service = stableService
    firstAttempt.makeKeychain = { name, group in
      if name == service { return failing }
      return env.keychain(name, group)
    }
    try firstAttempt.migrateIfNeeded()
    #expect(try env.store.load()?.identity == .signedOut)
    #expect(try journal.hasItem(forKey: "clerkSharedSessionOwnerSlotClearIntentV1"))

    try migration(env).migrateIfNeeded()
    #expect(try env.store.load()?.identity == .signedOut)
    #expect(try !journal.hasItem(forKey: "clerkSharedSessionOwnerSlotClearIntentV1"))
    #expect(try !env.keychain(stableService).hasItem(forKey: "clerkSharedSessionLocalIdentityV2"))
  }

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
  private let backing: InMemoryKeychain

  init(backing: InMemoryKeychain = InMemoryKeychain()) {
    self.backing = backing
  }

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

private struct MigrationReadFailingKeychain: KeychainStorage {
  func allItems() throws -> [String: Data] {
    throw KeychainError.unexpectedStatus(errSecInteractionNotAllowed)
  }

  func data(forKey _: String) throws -> Data? {
    throw KeychainError.unexpectedStatus(errSecInteractionNotAllowed)
  }

  func set(_: Data, forKey _: String) throws {}
  func deleteItem(forKey _: String) throws {}
  func hasItem(forKey _: String) throws -> Bool {
    false
  }
}
