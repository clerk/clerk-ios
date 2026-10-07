import Foundation
import Security

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

  let service: String
  let accessGroup: String?
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

    let status = withSecItemAccess { secItemClient.add(addQuery as CFDictionary, nil) }

    switch status {
    case errSecSuccess:
      return
    case errSecDuplicateItem:
      let updateQuery = baseQuery(for: key)
      let attributes: [String: Any] = [
        kSecValueData as String: data,
        kSecAttrAccessible as String: accessibility.secValue,
      ]
      let updateStatus = withSecItemAccess {
        secItemClient.update(updateQuery as CFDictionary, attributes as CFDictionary)
      }
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
    let status = withSecItemAccess { secItemClient.copyMatching(query as CFDictionary, &result) }

    switch status {
    case errSecSuccess:
      return result as? Data
    case errSecItemNotFound:
      return nil
    default:
      throw KeychainError.unexpectedStatus(status)
    }
  }

  func deleteItem(forKey key: String) throws {
    let status = withSecItemAccess { secItemClient.delete(baseQuery(for: key) as CFDictionary) }
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

    let status = withSecItemAccess { secItemClient.copyMatching(query as CFDictionary, nil) }
    switch status {
    case errSecSuccess:
      return true
    case errSecItemNotFound:
      return false
    default:
      throw KeychainError.unexpectedStatus(status)
    }
  }

  // MARK: - Helpers

  #if os(macOS)
  /// The file-based macOS keychain can deadlock when two threads call it at once: a read and a
  /// write take its keychain and item locks in opposite orders.
  private static let fileKeychainLock = NSLock()
  #endif

  private func withSecItemAccess(_ body: () -> OSStatus) -> OSStatus {
    #if os(macOS)
    if !useDataProtectionKeychain {
      return Self.fileKeychainLock.withLock(body)
    }
    #endif
    return body()
  }

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
