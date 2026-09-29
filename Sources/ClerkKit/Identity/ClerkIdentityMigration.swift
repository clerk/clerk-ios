//
//  ClerkIdentityMigration.swift
//  Clerk
//

import Foundation

struct ClerkIdentityMigration {
  static let markerValue = "3"
  static let clearedMarkerValue = "cleared"

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
    let acceptedIdentity: ClerkIdentitySnapshot?
  }

  private struct ClearIntent: Decodable {
    let localIdentityService: String
    let slotService: String
    let slotAccessGroup: String
    let slotAccount: String
  }

  let store: ClerkIdentityStore
  let legacyKeychain: any KeychainStorage
  let markerKeychain: any KeychainStorage
  let configuredService: String
  let accessGroup: String?
  let ownerIdentifier: String?
  let instanceFingerprint: String
  var readsLegacyItems = true
  var finalizes = true
  /// It is only read, because deleting without a group would also match siblings' items.
  var appLocalLegacyKeychain: (any KeychainStorage)?
  var makeKeychain: (_ service: String, _ accessGroup: String?) -> any KeychainStorage = Self.liveKeychain

  static func recordClear(in markerKeychain: any KeychainStorage) throws {
    let marker = ClerkKeychainKey.identityMigrated.rawValue
    guard try markerKeychain.string(forKey: marker) != markerValue else { return }
    try markerKeychain.set(clearedMarkerValue, forKey: marker)
  }

  func migrateIfNeeded() throws {
    let marker = ClerkKeychainKey.identityMigrated.rawValue
    let state = try markerKeychain.string(forKey: marker)
    guard state != Self.markerValue else { return }

    let clearIntent = loadClearIntent()
    let wasCleared = state == Self.clearedMarkerValue || clearIntent != nil
    if !wasCleared, let identity = try loadAtomicIdentity() ?? loadLegacyIdentity() {
      let existing: ClerkIdentitySnapshot?
      do {
        existing = try store.load()?.identity
      } catch ClerkIdentityStoreError.otherInstance {
        existing = nil
      }
      if existing == nil || (existing?.hasSession != true && identity.hasSession) {
        try store.save(identity)
      }
    }

    guard finalizes, removeEarlierStorage(clearIntent: clearIntent) else { return }
    try markerKeychain.set(Self.markerValue, forKey: marker)
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

  private func loadClearIntent() -> ClearIntent? {
    guard let data = try? clearJournal?.data(forKey: Self.clearIntentKey) else { return nil }
    return try? JSONDecoder.clerkDecoder.decode(ClearIntent.self, from: data)
  }

  private func loadAtomicIdentity() throws -> ClerkIdentitySnapshot? {
    let keychain = makeKeychain(stableIdentityService, nil)
    guard let data = try keychain.data(forKey: Self.atomicRecordKey),
          let record = try? JSONDecoder.clerkDecoder.decode(AtomicRecord.self, from: data)
    else {
      return nil
    }
    return try? record.acceptedIdentity?.validated()
  }

  private func loadLegacyIdentity() throws -> ClerkIdentitySnapshot? {
    guard readsLegacyItems else { return nil }
    return try loadLegacyIdentity(from: legacyKeychain)
      ?? appLocalLegacyKeychain.flatMap { try loadLegacyIdentity(from: $0) }
  }

  private func loadLegacyIdentity(from legacyKeychain: any KeychainStorage) throws -> ClerkIdentitySnapshot? {
    guard let token = try legacyKeychain.string(
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    ).nilIfEmpty else {
      return nil
    }
    let client = try legacyKeychain.data(forKey: ClerkKeychainKey.cachedClient.rawValue).flatMap {
      try? JSONDecoder.clerkDecoder.decode(Client.self, from: $0)
    }
    let serverDate = try legacyKeychain.string(forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)
      .flatMap(TimeInterval.init)
      .map(Date.init(timeIntervalSince1970:))
    return try ClerkIdentitySnapshot(
      state: client == nil ? .cleared : .present,
      deviceToken: token,
      client: client,
      serverDate: serverDate
    ).validated()
  }

  /// Deletes every earlier copy of the identity. Separate items in an access group are left
  /// for sibling apps still on an earlier SDK, which read them; a clear removes them.
  private func removeEarlierStorage(clearIntent: ClearIntent?) -> Bool {
    var deletions: [(any KeychainStorage, String)] = accessGroup == nil
      ? Self.legacyIdentityKeys.map { (legacyKeychain, $0.rawValue) }
      : []
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
    if let clearJournal {
      deletions.append((clearJournal, Self.clearIntentKey))
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

extension ClerkIdentitySnapshot {
  fileprivate var hasSession: Bool {
    client?.sessions.isEmpty == false
  }
}
