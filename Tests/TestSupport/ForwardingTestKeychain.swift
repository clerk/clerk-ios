@testable import ClerkKit
import Foundation

/// Forwards ordinary storage operations so failure-injection stores only override what changes.
/// Enumeration and conditional writes remain explicit, preserving each store's capabilities.
protocol ForwardingTestKeychain: KeychainStorage {
  var backing: InMemoryKeychain { get }
}

extension ForwardingTestKeychain {
  func set(_ data: Data, forKey key: String) throws {
    try backing.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    try backing.data(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    try backing.deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try backing.hasItem(forKey: key)
  }
}
