import CryptoKit
import Foundation

/// Keeps the SDK 1.5 wire fields ordered without changing the current merge protocol.
/// Persist before sending: retries of the same snapshot reuse its version, while
/// subsequent logins can advance past a clear even after a restart or clock change.
enum WatchSyncLegacyPublication {
  private struct Record: Codable {
    let fingerprint: String?
    let version: Int
  }

  static func version(for state: WatchSyncState, store: ClerkIdentityStore,
                      legacyKeychain: any KeychainStorage) throws -> Int?
  {
    // An empty installation has not requested that an older paired app clear itself.
    guard !state.isCleared || state.clearGeneration > 0 else { return nil }
    let previous = try load(in: store)
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
    // Swift Int is 32-bit on arm64_32 Watch devices. Wall-clock milliseconds
    // do not fit; the persisted counter already supplies the required ordering.
    guard floor < Int.max else { throw KeychainError.invalidStringEncoding }
    let version = floor + 1
    try store.clearJournal.set(JSONEncoder.clerkEncoder.encode(Record(fingerprint: fingerprint, version: version)), forKey: key(in: store))
    return version
  }

  /// SDK 1.5 advances its counters after receiving a peer's version. Preserve
  /// that floor even when its identity loses, so our reply remains readable.
  static func observePeerVersion(in payload: WatchSyncPayload, store: ClerkIdentityStore,
                                 legacyKeychain: any KeychainStorage) throws
  {
    guard payload.isLegacy, let version = payload.legacyVersion else { return }
    let versions = [version.token, version.auth].compactMap { $0 }
    guard versions.allSatisfy({ $0 >= 0 }) else { throw KeychainError.invalidStringEncoding }
    guard let received = versions.max() else { return }
    let previous = try load(in: store)
    let floor = try previous?.version ?? legacyFloor(in: legacyKeychain)
    guard received > floor else { return }
    // Invalidate the fingerprint: the next publication must advance beyond
    // this received version, even when our identity has not changed.
    try store.clearJournal.set(JSONEncoder.clerkEncoder.encode(Record(fingerprint: nil, version: received)), forKey: key(in: store))
  }

  private static func key(in store: ClerkIdentityStore) -> String {
    "\(store.key).watchPublication.\(SharedSessionNamespace.sha256(store.watchSyncOwnerIdentifier))"
  }

  private static func load(in store: ClerkIdentityStore) throws -> Record? {
    let record = try store.clearJournal.data(forKey: key(in: store)).map { try JSONDecoder.clerkDecoder.decode(Record.self, from: $0) }
    if let record, record.version < 0 { throw KeychainError.invalidStringEncoding }
    return record
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
