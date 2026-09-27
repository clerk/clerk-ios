import Foundation
import Security

/// Errors that can occur when interacting with the keychain.
enum KeychainError: Error, LocalizedError {
  case unexpectedStatus(OSStatus)
  case invalidStringEncoding

  var isMissingEntitlement: Bool {
    guard case .unexpectedStatus(errSecMissingEntitlement) = self else {
      return false
    }
    return true
  }

  var errorDescription: String? {
    switch self {
    case .unexpectedStatus(let status):
      if let message = SecCopyErrorMessageString(status, nil) as String? {
        "Keychain operation failed with OSStatus \(status): \(message)"
      } else {
        "Keychain operation failed with OSStatus \(status)."
      }
    case .invalidStringEncoding:
      "Keychain item data could not be decoded as a UTF-8 string."
    }
  }

  var failureReason: String? {
    switch self {
    case .unexpectedStatus(errSecMissingEntitlement):
      "The app is not signed with the configured Keychain access group. Enable Keychain Sharing and make sure Clerk.Options.keychainConfig.accessGroup matches a signed keychain-access-groups entitlement."
    case .unexpectedStatus:
      nil
    case .invalidStringEncoding:
      "The stored Keychain item is not valid UTF-8 data."
    }
  }
}

/// Lightweight interface describing the operations the Clerk SDK needs from a keychain.
protocol KeychainStorage: Sendable {
  func set(_ data: Data, forKey key: String) throws
  func data(forKey key: String) throws -> Data?
  func deleteItem(forKey key: String) throws
  func hasItem(forKey key: String) throws -> Bool
  /// Reads items in this storage's service and access group for legacy migration.
  func allItems() throws -> [String: Data]
  func dataForConditionalUpdate(forKey key: String) throws -> Data?
  /// Atomically creates an absent item, or replaces exactly the expected revision.
  /// A conflict returns false and must never fall back to an unconditional write.
  func compareAndSwap(_ data: Data, forKey key: String, expectedRevision: UUID?, newRevision: UUID) throws -> Bool
}

extension KeychainStorage {
  func allItems() throws -> [String: Data] {
    throw KeychainError.unexpectedStatus(errSecUnimplemented)
  }

  func dataForConditionalUpdate(forKey key: String) throws -> Data? {
    try data(forKey: key)
  }

  func compareAndSwap(_: Data, forKey _: String, expectedRevision _: UUID?, newRevision _: UUID) throws -> Bool {
    // Custom stores must provide a real atomic implementation, not read-then-set.
    throw KeychainError.unexpectedStatus(errSecUnimplemented)
  }

  func set(_ value: String, forKey key: String) throws {
    try set(Data(value.utf8), forKey: key)
  }

  func string(forKey key: String) throws -> String? {
    guard let data = try data(forKey: key) else { return nil }
    guard let string = String(data: data, encoding: .utf8) else {
      throw KeychainError.invalidStringEncoding
    }
    return string
  }
}
