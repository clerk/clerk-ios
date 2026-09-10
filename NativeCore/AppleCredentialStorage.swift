import CryptoKit
import Foundation
import Security

public struct LegacyKeychainConfiguration: Sendable {
  public let service: String?
  public let accessGroup: String?
  public let publishableKey: String?
  let installationAccessGroup: String?
  public init(service: String? = nil, accessGroup: String? = nil, publishableKey: String? = nil) {
    installationAccessGroup = accessGroup
    let group = accessGroup?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.service = service
    self.accessGroup = group?.isEmpty == false ? group : nil
    self.publishableKey = publishableKey?.trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

struct SecurityItemClient {
  let add: @Sendable (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
  let update: @Sendable (CFDictionary, CFDictionary) -> OSStatus
  let copyMatching: @Sendable (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
  static let system = SecurityItemClient(add: { SecItemAdd($0, $1) }, update: { SecItemUpdate($0, $1) }, copyMatching: { SecItemCopyMatching($0, $1) })
}

public actor KeychainCredentialStorage: CredentialStorage {
  public enum Purpose: String, Sendable { case client, magicLink, biometricCredentials, biometricCleanup }
  private let purpose: Purpose
  private struct Record: Codable { let schemaVersion: Int; let credential: String? }
  private let service: String
  private let applicationIdentifier: String
  private let publishableKey: String
  private let frontendAPI: URL
  private let legacy: LegacyKeychainConfiguration
  private let items: SecurityItemClient
  public init(publishableKey: String, frontendAPI: URL, applicationIdentifier: String = Bundle.main.bundleIdentifier ?? "Clerk", legacy: LegacyKeychainConfiguration = .init(), purpose: Purpose = .client) {
    self.init(publishableKey: publishableKey, frontendAPI: frontendAPI, applicationIdentifier: applicationIdentifier, legacy: legacy, purpose: purpose, items: .system)
  }

  init(publishableKey: String, frontendAPI: URL, applicationIdentifier: String, legacy: LegacyKeychainConfiguration = .init(), purpose: Purpose = .client, items: SecurityItemClient) {
    self.items = items
    self.purpose = purpose
    self.publishableKey = publishableKey
    self.frontendAPI = frontendAPI
    self.applicationIdentifier = applicationIdentifier
    self.legacy = legacy
    service = "\(applicationIdentifier).clerk.core.v2.\(Self.hash(publishableKey))"
  }

  public func read() throws -> String? {
    try Task.checkCancellation()
    if let data = try readItem(service: service, account: purpose.rawValue) {
      let record = try JSONDecoder().decode(Record.self, from: data)
      guard record.schemaVersion == 1 else { throw CoreError(code: "unsupported_credential_record") }
      return record.credential
    }
    let credential = try migrateLegacy()
    try save(credential)
    return credential
  }

  public func write(_ value: String) throws {
    try Task.checkCancellation(); try save(value)
  }

  public func remove() throws {
    try Task.checkCancellation()
    // An empty record prevents a restart from importing an older credential again.
    try save(nil)
  }

  private func save(_ value: String?) throws {
    let data = try JSONEncoder().encode(Record(schemaVersion: 1, credential: value))
    let query = itemQuery(service: service, account: purpose.rawValue)
    var insertion = query
    insertion[kSecValueData as String] = data
    insertion[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    let status = items.add(insertion as CFDictionary, nil)
    if status == errSecDuplicateItem {
      let updateStatus = items.update(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
      guard updateStatus == errSecSuccess else { throw storageError("secure_storage_write_failed", status: updateStatus) }
    } else if status != errSecSuccess { throw storageError("secure_storage_write_failed", status: status) }
  }

  private func migrateLegacy() throws -> String? {
    if purpose != .client {
      guard legacy.publishableKey == publishableKey else { return nil }
      guard purpose != .biometricCleanup else { return nil }
      let account = purpose == .magicLink ? "pendingMagicLinkFlow" : "trustedDeviceCredentials"
      let service = legacy.service ?? applicationIdentifier
      let data = try readItem(service: service, account: account)
        ?? readLegacyItem(service: service, account: account, accessGroup: legacy.accessGroup)
      return data.flatMap { String(data: $0, encoding: .utf8) }
    }
    var origin = frontendAPI.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
    while origin.hasSuffix("/") {
      origin.removeLast()
    }
    let fingerprint = Self.hash("clerk.shared-session-sync.v2\u{1F}\(origin)\u{1F}\(publishableKey.trimmingCharacters(in: .whitespacesAndNewlines))")
    // The previous major journals a destructive clear before removing its local
    // identity. A crash can leave the old token present; do not adopt it again.
    if try hasPendingLegacyClear(fingerprint: fingerprint) { return nil }
    let identityService = "\(applicationIdentifier).clerk.identity.v2.\(fingerprint)"
    if let data = try readItem(service: identityService, account: "clerkSharedSessionLocalIdentityV2") {
      let record = try JSONDecoder().decode(JSONValue.self, from: data).object()
      let identity: [String: JSONValue]
      if let version = record["schema_version"] {
        guard version == .number(1), let accepted = try record["accepted_identity"]?.optional({ try $0.object() }) else { return nil }
        identity = accepted
      } else {
        // Earlier revisions stored the identity directly, before the envelope.
        identity = record
      }
      guard let token = try legacyCredential(in: identity) else { return nil }
      if let pending = try record["pending_publication"]?.optional({ try $0.object() }),
         try legacyCredential(in: pending) != token { return nil }
      return token
    }
    // Adoption makes this app's local identity authoritative even when empty.
    // The previous major retains this marker through a clear so older shared
    // credentials (including a sibling's later writes) cannot restore it.
    if let marker = try readItem(service: identityService, account: "clerkSharedSessionSyncAdoptedV2"),
       String(data: marker, encoding: .utf8) == "2" { return nil }
    guard legacy.publishableKey == publishableKey else { return nil }
    guard let data = try readLegacyItem(service: legacy.service ?? applicationIdentifier, account: "clerkDeviceToken", accessGroup: legacy.accessGroup),
          let token = String(data: data, encoding: .utf8), !token.isEmpty else { return nil }
    return token
  }

  private func legacyCredential(in identity: [String: JSONValue]) throws -> String? {
    switch identity["state"] {
    case .string("present"):
      guard case .object = identity["client"] else { return nil }
    case .string("cleared"):
      // The previous major also used this state for a token awaiting canonical refresh.
      guard identity["client"] == nil || identity["client"] == .null else { return nil }
    default: return nil
    }
    guard let token = try identity["device_token"]?.optional({ try $0.string() }),
          !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
    return token
  }

  private func hasPendingLegacyClear(fingerprint: String) throws -> Bool {
    guard let data = try readItem(service: "\(applicationIdentifier).clerk.shared-session-clear-recovery.v1", account: "clerkSharedSessionOwnerSlotClearIntentV1") else { return false }
    let intent = try JSONDecoder().decode(JSONValue.self, from: data).object()
    let required = ["local_identity_service", "slot_service", "slot_access_group", "slot_account", "instance_fingerprint", "owner_identifier"]
    guard intent["schema_version"] == .number(1),
          intent["owner_identifier"] == .string(applicationIdentifier),
          required.allSatisfy({ (try? intent[$0]?.string().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) == false })
    else {
      throw CoreError(code: "invalid_legacy_clear_intent")
    }
    return intent["instance_fingerprint"] == .string(fingerprint)
  }

  private func itemQuery(service: String, account: String, accessGroup: String? = nil) -> [String: Any] {
    var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
    return query
  }

  private func readLegacyItem(service: String, account: String, accessGroup: String?) throws -> Data? {
    #if os(macOS)
    if let accessGroup, let data = try readItem(service: service, account: account, accessGroup: accessGroup, useDataProtectionKeychain: true) { return data }
    #endif
    return try readItem(service: service, account: account, accessGroup: accessGroup)
  }

  private func readItem(service: String, account: String, accessGroup: String? = nil, useDataProtectionKeychain: Bool = false) throws -> Data? {
    var query = itemQuery(service: service, account: account, accessGroup: accessGroup)
    if useDataProtectionKeychain { query[kSecUseDataProtectionKeychain as String] = true }
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var value: CFTypeRef?
    let status = items.copyMatching(query as CFDictionary, &value)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = value as? Data else { throw storageError("secure_storage_read_failed", status: status) }
    return data
  }

  private func storageError(_ code: String, status: OSStatus) -> CoreError {
    let guidance = status == errSecMissingEntitlement ? " Check Keychain Sharing entitlements and the configured accessGroup." : ""
    return CoreError(code: code, message: "Keychain operation failed (OSStatus \(status)).\(guidance)", details: .object(["osStatus": .number(Double(status))]))
  }

  private static func hash(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
  }
}
