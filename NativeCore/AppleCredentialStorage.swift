import CryptoKit
import Foundation
import Security

public struct LegacyKeychainConfiguration: Sendable {
  public let service: String?
  public let accessGroup: String?
  public let publishableKey: String?
  public init(service: String? = nil, accessGroup: String? = nil, publishableKey: String? = nil) {
    self.service = service; self.accessGroup = accessGroup; self.publishableKey = publishableKey
  }
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
  public init(publishableKey: String, frontendAPI: URL, applicationIdentifier: String = Bundle.main.bundleIdentifier ?? "Clerk", legacy: LegacyKeychainConfiguration = .init(), purpose: Purpose = .client) {
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
    let status = SecItemAdd(insertion as CFDictionary, nil)
    if status == errSecDuplicateItem {
      guard SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary) == errSecSuccess else { throw CoreError(code: "secure_storage_write_failed") }
    } else if status != errSecSuccess { throw CoreError(code: "secure_storage_write_failed") }
  }

  private func migrateLegacy() throws -> String? {
    if purpose != .client {
      guard legacy.publishableKey == publishableKey else { return nil }
      guard purpose != .biometricCleanup else { return nil }
      let account = purpose == .magicLink ? "pendingMagicLinkFlow" : "trustedDeviceCredentials"
      let service = legacy.service ?? applicationIdentifier
      let data = try readItem(service: service, account: account)
        ?? readItem(service: service, account: account, accessGroup: legacy.accessGroup)
      return data.flatMap { String(data: $0, encoding: .utf8) }
    }
    var origin = frontendAPI.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
    while origin.hasSuffix("/") {
      origin.removeLast()
    }
    let fingerprint = Self.hash("clerk.shared-session-sync.v2\u{1F}\(origin)\u{1F}\(publishableKey.trimmingCharacters(in: .whitespacesAndNewlines))")
    let identityService = "\(applicationIdentifier).clerk.identity.v2.\(fingerprint)"
    if let data = try readItem(service: identityService, account: "clerkSharedSessionLocalIdentityV2") {
      let record = try JSONDecoder().decode(JSONValue.self, from: data).object()
      guard record["schemaVersion"] == .number(1),
            let identity = try record["acceptedIdentity"]?.optional({ try $0.object() }),
            identity["state"] == .string("present"),
            let token = try identity["deviceToken"]?.optional({ try $0.string() }), !token.isEmpty else { return nil }
      if let pending = try record["pendingPublication"]?.optional({ try $0.object() }),
         pending["state"] != .string("present") || pending["deviceToken"] != .string(token) { return nil }
      return token
    }
    guard legacy.publishableKey == publishableKey else { return nil }
    guard let data = try readItem(service: legacy.service ?? applicationIdentifier, account: "clerkDeviceToken", accessGroup: legacy.accessGroup),
          let token = String(data: data, encoding: .utf8), !token.isEmpty else { return nil }
    return token
  }

  private func itemQuery(service: String, account: String, accessGroup: String? = nil) -> [String: Any] {
    var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
    return query
  }

  private func readItem(service: String, account: String, accessGroup: String? = nil) throws -> Data? {
    var query = itemQuery(service: service, account: account, accessGroup: accessGroup)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    var value: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &value)
    if status == errSecItemNotFound { return nil }
    guard status == errSecSuccess, let data = value as? Data else { throw CoreError(code: "secure_storage_read_failed") }
    return data
  }

  private static func hash(_ value: String) -> String {
    SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
  }
}
