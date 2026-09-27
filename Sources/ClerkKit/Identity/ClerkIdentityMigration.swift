//
//  ClerkIdentityMigration.swift
//  Clerk
//

import Foundation

/// Moves an existing identity into ``ClerkIdentityStore`` once per app, then removes
/// the storage used by earlier SDK versions.
///
/// Sources, in order of preference:
/// 1. The winning SDK 1.5 publication, including this app's pending publication.
/// 2. The atomic app-local record, if no publication exists.
/// 3. A current-format identity in the configured local or previous bundle-ID service.
/// 4. The earlier separate device-token item; a refresh supplies its matching Client.
///
/// A shared-session clear that was interrupted in SDK 1.5 is honored by not migrating
/// any identity. When another app in the access group already wrote the shared record,
/// that record is authoritative, even when signed out.
///
/// The migration is marked done only after every earlier copy was deleted, so a failed
/// deletion is retried on the next launch.
struct ClerkIdentityMigration {
  static let markerValue = "4"

  /// Earlier-layout identity items in the configured Keychain.
  static let legacyIdentityKeys: [ClerkKeychainKey] = [
    .clerkDeviceToken,
    .cachedClient,
    .cachedClientServerDate,
    .sharedSessionSyncAuthState,
    .sharedSessionSyncAuthVersion,
    .sharedSessionSyncEnvironmentVersion,
    .sharedSessionSyncDeviceTokenState,
    .sharedSessionSyncDeviceTokenVersion,
  ]

  private static let atomicRecordKey = "clerkSharedSessionLocalIdentityV2"
  private static let clearIntentKey = "clerkSharedSessionOwnerSlotClearIntentV1"

  private struct AtomicRecord: Decodable {
    let schemaVersion: Int
    let acceptedIdentity: ClerkIdentitySnapshot?
    let pendingPublication: Publication?
    let requiresLegacyAdoptionPublication: Bool?
  }

  private struct Publication: Decodable, Equatable {
    let id: UUID
    let originOwnerIdentifier: String
    let generation: UInt64
    let identity: ClerkIdentitySnapshot

    private enum CodingKeys: CodingKey { case id, originOwnerIdentifier, generation }

    init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      id = try container.decode(UUID.self, forKey: .id)
      originOwnerIdentifier = try container.decode(String.self, forKey: .originOwnerIdentifier)
      generation = try container.decode(UInt64.self, forKey: .generation)
      identity = try ClerkIdentitySnapshot(from: decoder).validated()
    }
  }

  private struct ClearIntent: Decodable {
    let localIdentityService: String
    let slotService: String
    let slotAccessGroup: String
    let slotAccount: String
  }

  let store: ClerkIdentityStore
  /// The configured Keychain, which held the earlier separate identity items.
  let legacyKeychain: any KeychainStorage
  /// App-local Keychain that records this app's migration.
  let markerKeychain: any KeychainStorage
  let configuredService: String
  let accessGroup: String?
  let ownerIdentifier: String?
  let instanceFingerprint: String
  /// The previous bundle-ID service when first enabling sharing with a common service.
  var previousAppLocalService: String?
  /// Apps that adopted shared-session sync in SDK 1.5 left stale separate items behind, so only
  /// apps that never adopted it read them.
  var readsLegacyItems = true
  var readsSharedLegacyItems = true
  /// Only a group identity adopts sibling publications. An app that turned sync off stays local.
  var readsSharedSlots = true
  /// `false` while the app cannot reach its access group: the identity is copied to the fallback
  /// store, but earlier copies are kept so the migration runs again once the group is reachable.
  var finalizes = true
  var makeKeychain: @Sendable (_ service: String, _ accessGroup: String?) -> any KeychainStorage = Self.liveKeychain

  func migrateIfNeeded() throws {
    try store.recoverPendingClear()
    let marker = "\(ClerkKeychainKey.identityMigrated.rawValue).\(instanceFingerprint)"
    let alreadyMigrated = try markerKeychain.string(forKey: marker) == Self.markerValue

    let clearIntent = alreadyMigrated ? nil : try loadClearIntent()
    // An existing record (including a clear tombstone) is authoritative. Importing
    // an old signed-in copy over it could undo another app's sign-out.
    if try store.load() == nil {
      do {
        if clearIntent != nil {
          try store.save(.signedOut, replacing: nil)
        } else if !alreadyMigrated, let identity = try loadAtomicIdentity() {
          try store.save(identity, replacing: nil)
        } else if let record = try loadCurrentFormatIdentity() {
          // The old migration marker only describes format adoption. Moving to
          // another service/backend must still carry the complete current record.
          try store.importRecord(record, replacing: nil)
        } else if !alreadyMigrated, let identity = try loadLegacyIdentity() {
          try store.save(identity, replacing: nil)
        }
      } catch ClerkIdentityStoreError.writeConflict {
        // A concurrent creator won. Verify that it is a supported record before cleanup.
        _ = try store.load()
      }
    }

    guard !alreadyMigrated else { return }
    guard finalizes, removeEarlierStorage(clearIntent: clearIntent) else { return }
    try markerKeychain.set(Self.markerValue, forKey: marker)
  }

  // MARK: - Sources

  private func loadCurrentFormatIdentity() throws -> ClerkIdentityStore.Record? {
    var sources: [(any KeychainStorage, String)] = [(markerKeychain, configuredService)]
    if let previousAppLocalKeychain, let previousAppLocalService {
      sources.append((previousAppLocalKeychain, previousAppLocalService))
    }
    for (keychain, service) in sources {
      let source = ClerkIdentityStore(
        keychain: keychain, instanceFingerprint: instanceFingerprint,
        clearIntentKeychain: makeKeychain(stableIdentityService, nil),
        clearIntentScope: SharedSessionNamespace.sha256("\(service)\u{1F}\u{1F}false")
      )
      try source.recoverPendingClear()
      if let record = try source.load() { return record }
    }
    return nil
  }

  private var stableIdentityService: String {
    let owner = ownerIdentifier.nilIfEmpty ?? configuredService
    return "\(owner).clerk.identity.v2.\(instanceFingerprint)"
  }

  private var clearJournal: (any KeychainStorage)? {
    ownerIdentifier.nilIfEmpty.map {
      makeKeychain("\($0).clerk.shared-session-clear-recovery.v1", nil)
    }
  }

  private func loadClearIntent() throws -> ClearIntent? {
    guard let data = try clearJournal?.data(forKey: Self.clearIntentKey) else { return nil }
    return try JSONDecoder.clerkDecoder.decode(ClearIntent.self, from: data)
  }

  private func loadAtomicIdentity() throws -> ClerkIdentitySnapshot? {
    var publications = try loadPublishedIdentities()
    let keychain = makeKeychain(stableIdentityService, nil)
    guard let data = try keychain.data(forKey: Self.atomicRecordKey) else {
      return try winningPublication(publications)?.identity
    }
    struct Header: Decodable { let schemaVersion: Int? }
    let decoder = JSONDecoder.clerkDecoder
    let version = try decoder.decode(Header.self, from: data).schemaVersion
    guard let version else {
      return try winningPublication(publications)?.identity
        ?? decoder.decode(ClerkIdentitySnapshot.self, from: data).validated()
    }
    guard version == 1 else {
      throw ClerkIdentityStoreError.unsupportedSchemaVersion(version)
    }
    let record = try decoder.decode(AtomicRecord.self, from: data)
    if record.requiresLegacyAdoptionPublication == true, record.acceptedIdentity == nil {
      throw ClerkIdentityMigrationError.missingPublicationIdentity
    }
    if let pending = record.pendingPublication {
      guard pending.generation > 0, pending.originOwnerIdentifier == ownerIdentifier else {
        throw ClerkIdentityMigrationError.invalidPendingPublication
      }
      publications.append(pending)
    }
    // Bootstrap the new record from the old group's selected state, even if this
    // app has never joined it or has an older local copy. No legacy slot is written.
    return try winningPublication(publications)?.identity ?? record.acceptedIdentity?.validated()
  }

  private func loadPublishedIdentities() throws -> [Publication] {
    guard readsSharedSlots, readsSharedLegacyItems, finalizes, let accessGroup else { return [] }
    let slots = makeKeychain(Self.ownerSlotService(configuredService, instanceFingerprint), accessGroup)
    struct Slot: Decodable {
      let schemaVersion: Int
      let instanceFingerprint: String
      let slotOwnerIdentifier: String
      let event: Publication
    }
    return try slots.allItems().compactMap { account, data in
      guard account.hasPrefix("owner.") else { return nil }
      let slot = try JSONDecoder.clerkDecoder.decode(Slot.self, from: data)
      guard slot.instanceFingerprint == instanceFingerprint else { return nil }
      guard slot.schemaVersion == 2,
            !slot.slotOwnerIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            account == Self.ownerSlotAccount(instanceFingerprint, slot.slotOwnerIdentifier),
            slot.event.generation > 0,
            !slot.event.originOwnerIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else { throw ClerkIdentityMigrationError.invalidPublishedIdentity }
      return slot.event
    }
  }

  private func winningPublication(_ publications: [Publication]) throws -> Publication? {
    var unique: [UUID: Publication] = [:]
    for publication in publications {
      if let previous = unique[publication.id], previous != publication {
        throw ClerkIdentityMigrationError.invalidPublishedIdentity
      }
      unique[publication.id] = publication
    }
    // Same ordering as the slot reducer. Signed-in state has no special priority.
    return unique.values.max { lhs, rhs in
      if lhs.generation != rhs.generation { return lhs.generation < rhs.generation }
      switch (lhs.identity.serverDate, rhs.identity.serverDate) {
      case (nil, .some): return true
      case (.some, nil): return false
      case let (.some(left), .some(right)) where left != right: return left < right
      default: break
      }
      if lhs.originOwnerIdentifier != rhs.originOwnerIdentifier {
        return lhs.originOwnerIdentifier < rhs.originOwnerIdentifier
      }
      return lhs.id.uuidString < rhs.id.uuidString
    }
  }

  private func loadLegacyIdentity() throws -> ClerkIdentitySnapshot? {
    guard readsLegacyItems else { return nil }
    // Enabling sharing for the first time must include this app's existing local credentials.
    if let local = try loadLegacyIdentity(from: markerKeychain) { return local }
    if let previousAppLocalKeychain,
       let previous = try loadLegacyIdentity(from: previousAppLocalKeychain) { return previous }
    return readsSharedLegacyItems ? try loadLegacyIdentity(from: legacyKeychain) : nil
  }

  private var previousAppLocalKeychain: (any KeychainStorage)? {
    guard let service = previousAppLocalService.nilIfEmpty,
          service != configuredService else { return nil }
    return makeKeychain(service, nil)
  }

  private func loadLegacyIdentity(from source: any KeychainStorage) throws -> ClerkIdentitySnapshot? {
    guard let token = try source.string(
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    ).nilIfEmpty else {
      return nil
    }
    // Separate writes cannot prove that the cached Client belongs to this token.
    // Preserve the credential and let the next refresh establish a coherent identity.
    return try ClerkIdentitySnapshot(
      state: .cleared, deviceToken: token, client: nil, serverDate: nil
    ).validated()
  }

  // MARK: - Cleanup

  /// Deletes every earlier copy of the identity. Separate items in an access group are left
  /// for sibling apps still on an earlier SDK, which read them; a clear removes them.
  ///
  /// - Returns: `true` when every deletion succeeded.
  private func removeEarlierStorage(clearIntent: ClearIntent?) -> Bool {
    var deletions: [(any KeychainStorage, String)] = accessGroup == nil
      ? Self.legacyIdentityKeys.map { (legacyKeychain, $0.rawValue) }
      : []
    if accessGroup != nil {
      deletions += Self.legacyIdentityKeys.map { (markerKeychain, $0.rawValue) }
    }
    if let previousAppLocalKeychain {
      deletions += Self.legacyIdentityKeys.map { (previousAppLocalKeychain, $0.rawValue) }
    }
    deletions.append((makeKeychain(stableIdentityService, nil), Self.atomicRecordKey))
    if let ownerIdentifier = ownerIdentifier.nilIfEmpty, let accessGroup {
      deletions.append((
        makeKeychain(Self.ownerSlotService(configuredService, instanceFingerprint), accessGroup),
        Self.ownerSlotAccount(instanceFingerprint, ownerIdentifier)
      ))
    }
    if let clearIntent {
      deletions.append((makeKeychain(clearIntent.localIdentityService, nil), Self.atomicRecordKey))
      deletions.append((makeKeychain(clearIntent.slotService, clearIntent.slotAccessGroup), clearIntent.slotAccount))
    }

    var succeeded = true
    for (keychain, key) in deletions {
      do {
        try keychain.deleteItem(forKey: key)
      } catch {
        succeeded = false
        ClerkLogger.logError(error, message: "Failed to remove Clerk identity storage from an earlier SDK version")
      }
    }
    // Keep the clear intent until every credential it protects was removed.
    if succeeded, let clearJournal {
      do {
        try clearJournal.deleteItem(forKey: Self.clearIntentKey)
      } catch {
        ClerkLogger.logError(error, message: "Failed to remove the completed legacy clear intent")
        succeeded = false
      }
    }
    return succeeded
  }

  private static func ownerSlotService(_ configuredService: String, _ instanceFingerprint: String) -> String {
    "\(configuredService).\(SharedSessionNamespace.protocolIdentifier).\(instanceFingerprint)"
  }

  private static func ownerSlotAccount(_ instanceFingerprint: String, _ ownerIdentifier: String) -> String {
    let seed = "\(SharedSessionNamespace.protocolIdentifier)\u{1F}\(instanceFingerprint)\u{1F}\(ownerIdentifier)"
    return "owner.\(SharedSessionNamespace.sha256(seed))"
  }

  static func liveKeychain(service: String, accessGroup: String?) -> any KeychainStorage {
    #if os(macOS)
    SystemKeychain(service: service, accessGroup: accessGroup, useDataProtectionKeychain: accessGroup != nil)
    #else
    SystemKeychain(service: service, accessGroup: accessGroup)
    #endif
  }
}

enum ClerkIdentityMigrationError: Error {
  case missingPublicationIdentity
  case invalidPendingPublication
  case invalidPublishedIdentity
}
