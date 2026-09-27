@testable import ClerkKit
import Foundation
import Security

/// An in-memory keychain storage implementation for testing.
/// Data is stored in a dictionary and cleared when the test completes.
final class InMemoryKeychain: @unchecked Sendable, KeychainStorage {
  private let lock = NSLock()
  private var items: [String: Data] = [:]
  private var revisions: [String: UUID] = [:]

  func set(_ data: Data, forKey key: String) throws {
    lock.lock()
    defer { lock.unlock() }
    items[key] = data
  }

  func compareAndSwap(_ data: Data, forKey key: String, expectedRevision: UUID?, newRevision: UUID) throws -> Bool {
    lock.lock()
    defer { lock.unlock() }
    if let expectedRevision {
      guard items[key] != nil, revisions[key] == expectedRevision else { return false }
    } else if items[key] != nil {
      return false
    }
    items[key] = data
    revisions[key] = newRevision
    return true
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
    revisions.removeValue(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return items[key] != nil
  }

  var isEmpty: Bool {
    lock.lock()
    defer { lock.unlock() }
    return items.isEmpty
  }

  func allItems() throws -> [String: Data] {
    lock.withLock { items }
  }
}

final class SetFailingKeychain: @unchecked Sendable, KeychainStorage {
  enum Failure: Error {
    case set
  }

  func set(_: Data, forKey _: String) throws {
    throw Failure.set
  }

  func compareAndSwap(_: Data, forKey _: String, expectedRevision _: UUID?, newRevision _: UUID) throws -> Bool {
    throw Failure.set
  }

  func data(forKey _: String) throws -> Data? {
    nil
  }

  func deleteItem(forKey _: String) throws {}

  func hasItem(forKey _: String) throws -> Bool {
    false
  }
}

struct MissingEntitlementKeychain: KeychainStorage {
  private var error: KeychainError {
    .unexpectedStatus(errSecMissingEntitlement)
  }

  func set(_: Data, forKey _: String) throws {
    throw error
  }

  func data(forKey _: String) throws -> Data? {
    throw error
  }

  func deleteItem(forKey _: String) throws {
    throw error
  }

  func hasItem(forKey _: String) throws -> Bool {
    throw error
  }
}
