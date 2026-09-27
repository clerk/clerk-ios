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
