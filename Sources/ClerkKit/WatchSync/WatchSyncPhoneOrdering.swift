import Foundation

package struct WatchSyncLegacyVersion: Codable, Equatable {
  let token: Int?
  let auth: Int?
}

/// Receiver-side compatibility for the ordered SDK 1.5 phone stream. Stored with
/// the identity so a failed clear cannot advance its replay protection separately.
struct WatchSyncPhoneOrdering: Codable, Equatable {
  var version = WatchSyncLegacyVersion(token: nil, auth: nil)
  var usesCurrentSchema = false

  mutating func state(from payload: WatchSyncPayload, replacing local: WatchSyncState) throws -> WatchSyncState? {
    guard let incoming = payload.state else { return nil }
    guard payload.isLegacy else {
      usesCurrentSchema = true
      return incoming
    }
    guard !usesCurrentSchema else { return nil }
    let hasPreviousVersion = version.token != nil || version.auth != nil
    guard let incomingVersion = payload.legacyVersion else { return hasPreviousVersion ? nil : incoming }
    guard accept(incomingVersion, isClear: incoming.isCleared) else { return nil }
    // A versioned phone stream can advance past its earlier clear. A previously
    // unseen sign-in must not bypass a local clear.
    guard incoming.isCleared || local.clearGeneration == 0 || hasPreviousVersion else { return nil }
    let (generation, overflow) = local.clearGeneration.addingReportingOverflow(incoming.isCleared ? 1 : 0)
    guard !overflow else { throw KeychainError.invalidStringEncoding }
    return .init(
      deviceToken: incoming.deviceToken, client: incoming.client,
      serverDate: incoming.serverDate, clearGeneration: generation
    )
  }

  mutating func accept(_ incoming: WatchSyncLegacyVersion, isClear: Bool) -> Bool {
    guard !usesCurrentSchema,
          incoming.token.map({ $0 >= (version.token ?? 0) }) ?? true,
          incoming.auth.map({ $0 >= (version.auth ?? 0) }) ?? true else { return false }
    let newToken = incoming.token.map { $0 > (version.token ?? -1) } ?? false
    let newAuth = incoming.auth.map { $0 > (version.auth ?? -1) } ?? false
    guard isClear ? newToken : (newToken || newAuth) else { return false }
    version = .init(token: incoming.token ?? version.token, auth: incoming.auth ?? version.auth)
    return true
  }

  /// Retain only the previously committed phone stream before deleting SDK 1.5 metadata.
  /// The per-app journal keeps this bootstrap history independent of sibling apps.
  static func preserveLegacy(in keychain: any KeychainStorage, store: ClerkIdentityStore) throws {
    let legacy = try loadLegacy(in: keychain)
    guard legacy.version.token != nil || legacy.version.auth != nil else { return }
    let previous = try loadPreservedLegacy(in: store)
    var retained = previous ?? Self()
    retained.version = .init(
      token: [previous?.version.token, legacy.version.token].compactMap { $0 }.max(),
      auth: [previous?.version.auth, legacy.version.auth].compactMap { $0 }.max()
    )
    if retained != previous {
      try store.clearJournal.set(JSONEncoder.clerkEncoder.encode(retained), forKey: legacyKey(in: store))
    }
  }

  static func loadPreservedLegacy(in store: ClerkIdentityStore) throws -> Self? {
    guard let data = try store.clearJournal.data(forKey: legacyKey(in: store)) else { return nil }
    let retained = try JSONDecoder.clerkDecoder.decode(Self.self, from: data)
    guard retained.version.token.map({ $0 >= 0 }) ?? true,
          retained.version.auth.map({ $0 >= 0 }) ?? true else { throw KeychainError.invalidStringEncoding }
    return retained
  }

  private static func legacyKey(in store: ClerkIdentityStore) -> String {
    "\(store.key).legacyPhoneOrdering.\(SharedSessionNamespace.sha256(store.watchSyncOwnerIdentifier))"
  }

  static func loadLegacy(in keychain: any KeychainStorage) throws -> Self {
    // Only counters attributed to the phone can order its subsequent messages.
    // Watch-local counters are a different stream and must not become phone clears.
    struct Metadata: Decodable {
      let deviceTokenVersion: Int?
      let deviceTokenSource: String?
      let authVersion: Int?
      let authSource: String?
    }
    guard let data = try keychain.data(forKey: ClerkKeychainKey.watchSyncMetadata.rawValue) else { return Self() }
    let metadata = try JSONDecoder.clerkDecoder.decode(Metadata.self, from: data)
    // A staged version was not necessarily committed; allow that message to retry.
    let token = metadata.deviceTokenSource == "phone" ? metadata.deviceTokenVersion : nil
    let auth = metadata.authSource == "phone" ? metadata.authVersion : nil
    guard token.map({ $0 >= 0 }) ?? true, auth.map({ $0 >= 0 }) ?? true else { throw KeychainError.invalidStringEncoding }
    return Self(version: .init(token: token, auth: auth))
  }
}
