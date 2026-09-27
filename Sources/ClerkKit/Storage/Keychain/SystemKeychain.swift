import Foundation
import Security

/// A concrete keychain storage backed by the system Keychain services.
struct SystemKeychain: KeychainStorage {
  enum Accessibility {
    case afterFirstUnlockThisDeviceOnly

    var secValue: CFString {
      switch self {
      case .afterFirstUnlockThisDeviceOnly:
        kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      }
    }
  }

  private let service: String
  private let accessGroup: String?
  private let accessibility: Accessibility
  private let useDataProtectionKeychain: Bool
  private let secItemClient: SecItemClient

  init(
    service: String,
    accessGroup: String? = nil,
    accessibility: Accessibility = .afterFirstUnlockThisDeviceOnly,
    useDataProtectionKeychain: Bool = false,
    secItemClient: SecItemClient = .live
  ) {
    self.service = service
    self.accessGroup = accessGroup
    self.accessibility = accessibility
    self.useDataProtectionKeychain = useDataProtectionKeychain
    self.secItemClient = secItemClient
  }

  func set(_ data: Data, forKey key: String) throws {
    var addQuery = baseQuery(for: key)
    addQuery[kSecAttrAccessible as String] = accessibility.secValue
    addQuery[kSecValueData as String] = data

    let status = secItemClient.add(addQuery as CFDictionary, nil)

    switch status {
    case errSecSuccess:
      return
    case errSecDuplicateItem:
      let updateQuery = baseQuery(for: key)
      let attributes: [String: Any] = [
        kSecValueData as String: data,
        kSecAttrAccessible as String: accessibility.secValue,
      ]
      let updateStatus = secItemClient.update(updateQuery as CFDictionary, attributes as CFDictionary)
      guard updateStatus == errSecSuccess else {
        throw KeychainError.unexpectedStatus(updateStatus)
      }
    default:
      throw KeychainError.unexpectedStatus(status)
    }
  }

  func data(forKey key: String) throws -> Data? {
    var query = baseQuery(for: key)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = secItemClient.copyMatching(query as CFDictionary, &result)

    switch status {
    case errSecSuccess:
      return result as? Data
    case errSecItemNotFound:
      return nil
    default:
      throw KeychainError.unexpectedStatus(status)
    }
  }

  func compareAndSwap(_ data: Data, forKey key: String, expectedRevision: UUID?, newRevision: UUID) throws -> Bool {
    var query = baseQuery(for: key)
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrGeneric as String: Data(newRevision.uuidString.utf8),
      kSecAttrAccessible as String: accessibility.secValue,
    ]
    let status: OSStatus
    if let expectedRevision {
      query[kSecAttrGeneric as String] = Data(expectedRevision.uuidString.utf8)
      status = secItemClient.update(query as CFDictionary, attributes as CFDictionary)
      if status == errSecItemNotFound { return false }
    } else {
      query.merge(attributes) { _, new in new }
      status = secItemClient.add(query as CFDictionary, nil)
      if status == errSecDuplicateItem { return false }
    }
    guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    return true
  }

  func deleteItem(forKey key: String) throws {
    let status = secItemClient.delete(baseQuery(for: key) as CFDictionary)
    switch status {
    case errSecSuccess, errSecItemNotFound:
      return
    default:
      throw KeychainError.unexpectedStatus(status)
    }
  }

  func hasItem(forKey key: String) throws -> Bool {
    var query = baseQuery(for: key)
    query[kSecMatchLimit as String] = kSecMatchLimitOne
    query[kSecReturnAttributes as String] = false
    query[kSecReturnData as String] = false

    let status = secItemClient.copyMatching(query as CFDictionary, nil)
    switch status {
    case errSecSuccess:
      return true
    case errSecItemNotFound:
      return false
    default:
      throw KeychainError.unexpectedStatus(status)
    }
  }

  func allItems() throws -> [String: Data] {
    var query = baseQuery(for: "")
    query.removeValue(forKey: kSecAttrAccount as String)
    query[kSecReturnAttributes as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitAll
    var result: CFTypeRef?
    let status = secItemClient.copyMatching(query as CFDictionary, &result)
    if status == errSecItemNotFound { return [:] }
    guard status == errSecSuccess else { throw KeychainError.unexpectedStatus(status) }
    guard let items = result as? [[String: Any]] else {
      throw KeychainError.unexpectedStatus(errSecDecode)
    }
    return try items.reduce(into: [:]) { values, item in
      guard let account = item[kSecAttrAccount as String] as? String else {
        throw KeychainError.unexpectedStatus(errSecDecode)
      }
      // The macOS legacy Keychain cannot combine password data with match-all.
      // Read each account separately; a peer may have removed it since enumeration.
      values[account] = try data(forKey: account)
    }
  }

  // MARK: - Helpers

  private func baseQuery(for key: String) -> [String: Any] {
    var query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]

    if let accessGroup {
      query[kSecAttrAccessGroup as String] = accessGroup
    }

    if useDataProtectionKeychain {
      query[kSecUseDataProtectionKeychain as String] = kCFBooleanTrue
    }

    return query
  }

  /// Wraps Apple's global SecItem functions so unit tests can verify the
  /// generated keychain queries without touching the real system keychain.
  struct SecItemClient {
    let add: @Sendable (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    let update: @Sendable (CFDictionary, CFDictionary) -> OSStatus
    let copyMatching: @Sendable (CFDictionary, UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus
    let delete: @Sendable (CFDictionary) -> OSStatus

    static let live = Self(
      add: { SecItemAdd($0, $1) },
      update: { SecItemUpdate($0, $1) },
      copyMatching: { SecItemCopyMatching($0, $1) },
      delete: { SecItemDelete($0) }
    )
  }
}
