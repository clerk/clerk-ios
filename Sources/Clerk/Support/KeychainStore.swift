import Foundation
import SimpleKeychain

protocol KeychainStore: Sendable {
  func set(_ data: Data, forKey key: String) throws
  func set(_ string: String, forKey key: String) throws
  func data(forKey key: String) throws -> Data?
  func string(forKey key: String) throws -> String?
  func deleteItem(forKey key: String) throws
  func hasItem(forKey key: String) throws -> Bool
}

final class InMemoryKeychain: KeychainStore {
  private var storage: [String: Data] = [:]
  private let queue = DispatchQueue(label: "InMemoryKeychain.queue")

  func set(_ data: Data, forKey key: String) throws {
    queue.sync {
      storage[key] = data
    }
  }

  func set(_ string: String, forKey key: String) throws {
    guard let data = string.data(using: .utf8) else {
      throw SimpleKeychainError.cannotEncodeString
    }
    try set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    queue.sync { storage[key] }
  }

  func string(forKey key: String) throws -> String? {
    guard let data = try data(forKey: key) else { return nil }
    return String(data: data, encoding: .utf8)
  }

  func deleteItem(forKey key: String) throws {
    queue.sync { storage.removeValue(forKey: key) }
  }

  func hasItem(forKey key: String) throws -> Bool {
    queue.sync { storage[key] != nil }
  }
}

private enum SimpleKeychainError: Error {
  case cannotEncodeString
}
