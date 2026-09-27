//
//  InMemoryKeychain.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// An in-memory keychain storage implementation for testing and previews.
/// Data is stored in a dictionary and cleared when the container is deallocated.
package final class InMemoryKeychain: @unchecked Sendable, KeychainStorage {
  private let lock = NSLock()
  private var items: [String: Data] = [:]
  private var revisions: [String: UUID] = [:]

  package init() {}

  package func set(_ data: Data, forKey key: String) throws {
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

  package func data(forKey key: String) throws -> Data? {
    lock.lock()
    defer { lock.unlock() }
    return items[key]
  }

  package func deleteItem(forKey key: String) throws {
    lock.lock()
    defer { lock.unlock() }
    items.removeValue(forKey: key)
    revisions.removeValue(forKey: key)
  }

  package func hasItem(forKey key: String) throws -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return items[key] != nil
  }

  func allItems() throws -> [String: Data] {
    lock.withLock { items }
  }
}
