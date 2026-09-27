import Foundation

struct MigratingKeychainStorage: KeychainStorage {
  private let primary: any KeychainStorage
  private let fallback: any KeychainStorage

  init(
    primary: any KeychainStorage,
    fallback: any KeychainStorage
  ) {
    self.primary = primary
    self.fallback = fallback
  }

  func set(_ data: Data, forKey key: String) throws {
    try primary.set(data, forKey: key)
  }

  /// Legacy owner slots were written only to the primary Data Protection backend.
  /// Enumeration must not import stale items from the compatibility fallback.
  func allItems() throws -> [String: Data] {
    try primary.allItems()
  }

  /// Conditional records have one authoritative backend. Reading a fallback and
  /// copying it with set() could overwrite a concurrent primary write or a clear.
  func dataForConditionalUpdate(forKey key: String) throws -> Data? {
    try primary.dataForConditionalUpdate(forKey: key)
  }

  func compareAndSwap(_ data: Data, forKey key: String, expectedRevision: UUID?, newRevision: UUID) throws -> Bool {
    try primary.compareAndSwap(data, forKey: key, expectedRevision: expectedRevision, newRevision: newRevision)
  }

  func data(forKey key: String) throws -> Data? {
    if let data = try primary.data(forKey: key) {
      return data
    }

    guard let fallbackData = try fallback.data(forKey: key) else {
      return nil
    }

    do {
      try primary.set(fallbackData, forKey: key)
    } catch {
      return fallbackData
    }

    return fallbackData
  }

  func deleteItem(forKey key: String) throws {
    var deletionError: Error?

    do {
      try primary.deleteItem(forKey: key)
    } catch {
      deletionError = error
    }

    do {
      try fallback.deleteItem(forKey: key)
    } catch {
      deletionError = deletionError ?? error
    }

    if let deletionError {
      throw deletionError
    }
  }

  func hasItem(forKey key: String) throws -> Bool {
    if try primary.hasItem(forKey: key) {
      return true
    }

    return try fallback.hasItem(forKey: key)
  }
}
