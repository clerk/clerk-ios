import CryptoKit
import Foundation

/// Keeps the SDK 1.5 wire fields ordered without changing the current merge protocol.
/// Persist before sending: retries of the same snapshot reuse its version, while
/// subsequent logins can advance past a clear even after a restart or clock change.
enum WatchSyncLegacyPublication {
  private struct Record: Codable {
    let fingerprint: String
    let version: Int
  }

  static func version(for state: WatchSyncState, store: ClerkIdentityStore,
                      legacyKeychain: any KeychainStorage, now: Date = Date()) throws -> Int?
  {
    // An empty installation has not requested that an older paired app clear itself.
    guard !state.isCleared || state.clearGeneration > 0 else { return nil }
    let key = "\(store.key).watchPublication.\(SharedSessionNamespace.sha256(store.watchSyncOwnerIdentifier))"
    let previous = try store.clearJournal.data(forKey: key).map { try JSONDecoder.clerkDecoder.decode(Record.self, from: $0) }
    if let previous, previous.version < 0 { throw KeychainError.invalidStringEncoding }
    struct Snapshot: Encodable {
      let identity: ClerkIdentitySnapshot
      let clearGeneration: Int
    }
    let encoder = JSONEncoder.clerkEncoder
    encoder.outputFormatting = .sortedKeys
    let data = try encoder.encode(Snapshot(identity: ClerkIdentitySnapshot(
      state: state.client == nil ? .cleared : .present,
      deviceToken: state.deviceToken, client: state.client, serverDate: state.serverDate
    ), clearGeneration: state.clearGeneration))
    let fingerprint = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    if previous?.fingerprint == fingerprint { return previous?.version }
    let floor = try previous?.version ?? legacyFloor(in: legacyKeychain)
    guard floor < Int.max,
          let timestamp = Int(exactly: (now.timeIntervalSince1970 * 1000).rounded(.down)) else { throw KeychainError.invalidStringEncoding }
    let version = max(floor + 1, timestamp)
    try store.clearJournal.set(JSONEncoder.clerkEncoder.encode(Record(fingerprint: fingerprint, version: version)), forKey: key)
    return version
  }

  /// Reduce the old record to a non-secret numeric floor before deleting it.
  /// Also works before the first publication, including while Watch sync is off.
  static func preserveVersionFloor(in keychain: any KeychainStorage) throws {
    let floor = try legacyFloor(in: keychain)
    if floor > 0 { try keychain.set(String(floor), forKey: ClerkKeychainKey.watchSyncAuthVersion.rawValue) }
  }

  private static func legacyFloor(in keychain: any KeychainStorage) throws -> Int {
    // Pending versions may already have reached the peer; never reuse them for a
    // different identity. Older installations used separate string items instead.
    struct Metadata: Decodable {
      let deviceTokenVersion: Int?
      let authVersion: Int?
      let pendingDeviceTokenVersion: Int?
      let pendingAuthVersion: Int?
    }
    var versions: [Int] = []
    if let data = try keychain.data(forKey: ClerkKeychainKey.watchSyncMetadata.rawValue) {
      let record = try JSONDecoder.clerkDecoder.decode(Metadata.self, from: data)
      versions = [record.deviceTokenVersion, record.authVersion, record.pendingDeviceTokenVersion, record.pendingAuthVersion].compactMap { $0 }
    }
    versions += try [ClerkKeychainKey.watchSyncDeviceTokenVersion, .watchSyncAuthVersion].compactMap { key in
      guard let value = try keychain.string(forKey: key.rawValue) else { return nil }
      guard let version = Int(value) else { throw KeychainError.invalidStringEncoding }
      return version
    }
    guard versions.allSatisfy({ $0 >= 0 }) else { throw KeychainError.invalidStringEncoding }
    return versions.max() ?? 0
  }
}
