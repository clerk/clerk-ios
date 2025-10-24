import Foundation

@testable import ClerkKit

final class InMemoryKeychain: KeychainStorage {
  private let lock = NSLock()
  private var storage: [String: Data] = [:]

  func set(_ data: Data, forKey key: String) throws {
    lock.lock()
    storage[key] = data
    lock.unlock()
  }

  func data(forKey key: String) throws -> Data? {
    lock.lock()
    let data = storage[key]
    lock.unlock()
    return data
  }

  func deleteItem(forKey key: String) throws {
    lock.lock()
    storage.removeValue(forKey: key)
    lock.unlock()
  }

  func hasItem(forKey key: String) throws -> Bool {
    lock.lock()
    let exists = storage[key] != nil
    lock.unlock()
    return exists
  }
}

extension InMemoryKeychain: @unchecked Sendable {}
