import Foundation

/// Errors that can occur when interacting with the keychain.
enum KeychainError: Error {
  case unexpectedStatus(OSStatus)
  case invalidStringEncoding
}

/// Lightweight interface describing the operations the Clerk SDK needs from a keychain.
protocol KeychainStorage: Sendable {
  func set(_ data: Data, forKey key: String) throws
  func data(forKey key: String) throws -> Data?
  func deleteItem(forKey key: String) throws
  func hasItem(forKey key: String) throws -> Bool
}

extension KeychainStorage {
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

  func set(_ value: Double, forKey key: String) throws {
    var doubleValue = value
    let data = withUnsafeBytes(of: &doubleValue) { Data($0) }
    try set(data, forKey: key)
  }

  func double(forKey key: String) throws -> Double? {
    guard let data = try data(forKey: key) else { return nil }
    guard data.count == MemoryLayout<Double>.size else { return nil }
    return data.withUnsafeBytes { $0.load(as: Double.self) }
  }
}
