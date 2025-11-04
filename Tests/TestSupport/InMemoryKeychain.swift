import Foundation

@testable import ClerkKit

/// An in-memory keychain storage implementation for testing.
/// Data is stored in a dictionary and cleared when the test completes.
final class InMemoryKeychain: @unchecked Sendable, KeychainStorage {
  private let lock = NSLock()
  private var items: [String: Data] = [:]

  func set(_ data: Data, forKey key: String) throws {
    lock.lock()
    defer { lock.unlock() }
    items[key] = data
  }

  func data(forKey key: String) throws -> Data? {
    lock.lock()
    defer { lock.unlock() }
    return items[key]
  }

  func deleteItem(forKey key: String) throws {
    lock.lock()
    defer { lock.unlock() }
    items.removeValue(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return items[key] != nil
  }
}

