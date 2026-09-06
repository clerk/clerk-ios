import Foundation
import Security

public enum ClerkJSKeychainError: Error, Sendable, Equatable {
  case unexpectedStatus(OSStatus)

  public var isMissingEntitlement: Bool {
    self == .unexpectedStatus(errSecMissingEntitlement)
  }
}

struct ClerkJSKeychain {
  var service: String

  func set(_ data: Data, account: String) throws {
    var addQuery = baseQuery(account: account)
    addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    addQuery[kSecValueData as String] = data

    let status = SecItemAdd(addQuery as CFDictionary, nil)
    switch status {
    case errSecSuccess:
      return
    case errSecDuplicateItem:
      let attributes: [String: Any] = [
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      ]
      let updateStatus = SecItemUpdate(baseQuery(account: account) as CFDictionary, attributes as CFDictionary)
      guard updateStatus == errSecSuccess else {
        throw ClerkJSKeychainError.unexpectedStatus(updateStatus)
      }
    default:
      throw ClerkJSKeychainError.unexpectedStatus(status)
    }
  }

  func data(account: String) throws -> Data? {
    var query = baseQuery(account: account)
    query[kSecReturnData as String] = true
    query[kSecMatchLimit as String] = kSecMatchLimitOne

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    switch status {
    case errSecSuccess:
      return result as? Data
    case errSecItemNotFound:
      return nil
    default:
      throw ClerkJSKeychainError.unexpectedStatus(status)
    }
  }

  func delete(account: String) throws {
    let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
    switch status {
    case errSecSuccess, errSecItemNotFound:
      return
    default:
      throw ClerkJSKeychainError.unexpectedStatus(status)
    }
  }

  private func baseQuery(account: String) -> [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
  }
}

extension ClerkJSTokenCache {
  public static func keychain(service: String, account: String) -> ClerkJSTokenCache {
    let box = KeychainTokenBox(keychain: ClerkJSKeychain(service: service), account: account)
    return ClerkJSTokenCache(
      getToken: { await box.get() },
      saveToken: { await box.save($0) }
    )
  }
}

private actor KeychainTokenBox {
  let keychain: ClerkJSKeychain
  let account: String

  init(keychain: ClerkJSKeychain, account: String) {
    self.keychain = keychain
    self.account = account
  }

  func get() -> String {
    guard let data = try? keychain.data(account: account) else {
      return ""
    }
    return String(data: data, encoding: .utf8) ?? ""
  }

  func save(_ token: String) {
    if token.isEmpty {
      try? keychain.delete(account: account)
    } else {
      try? keychain.set(Data(token.utf8), account: account)
    }
  }
}
