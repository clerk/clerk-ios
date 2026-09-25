//
//  ClerkIdentityMigration.swift
//  Clerk
//

import Foundation

/// Moves an existing identity into ``ClerkIdentityStore`` once per app, then removes
/// the storage used by earlier SDK versions.
///
/// Sources, in order of preference:
/// 1. The atomic app-local record written by shared-session sync in SDK 1.5.
/// 2. The separate device-token, Client, and server-date items written before that.
///
/// A shared-session clear that was interrupted in SDK 1.5 is honored by not migrating
/// any identity. When another app in the access group already wrote the shared record,
/// that record is kept unless it is signed out and this app's identity is signed in.
///
/// The migration is marked done only after every earlier copy was deleted, so a failed
/// deletion is retried on the next launch.
struct ClerkIdentityMigration {
  static let markerValue = "3"

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
    let acceptedIdentity: ClerkIdentitySnapshot?
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
  /// Apps that adopted shared-session sync in SDK 1.5 left stale separate items behind, so only
  /// apps that never adopted it read them.
  var readsLegacyItems = true
  /// `false` while the app cannot reach its access group: the identity is copied to the fallback
  /// store, but earlier copies are kept so the migration runs again once the group is reachable.
  var finalizes = true
  var makeKeychain: (_ service: String, _ accessGroup: String?) -> any KeychainStorage = Self.liveKeychain

  func migrateIfNeeded() throws {
    let marker = ClerkKeychainKey.identityMigrated.rawValue
    guard try markerKeychain.string(forKey: marker) != Self.markerValue else { return }

    let clearIntent = loadClearIntent()
    if clearIntent == nil, let identity = try loadAtomicIdentity() ?? loadLegacyIdentity() {
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

  // MARK: - Sources

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
    guard readsLegacyItems, let token = try legacyKeychain.string(
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

  // MARK: - Cleanup

  /// Deletes every earlier copy of the identity. Separate items in an access group are left
  /// for sibling apps still on an earlier SDK, which read them; a clear removes them.
  ///
  /// - Returns: `true` when every deletion succeeded.
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
