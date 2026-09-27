import Foundation

/// Keeps failed layout discovery retryable without directing any operation to a guessed backend.
struct DeferredKeychainStorage: KeychainStorage {
  let resolve: @Sendable () throws -> any KeychainStorage

  func set(_ data: Data, forKey key: String) throws {
    try resolve().set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    try resolve().data(forKey: key)
  }

  func dataForConditionalUpdate(forKey key: String) throws -> Data? {
    try resolve().dataForConditionalUpdate(forKey: key)
  }

  func compareAndSwap(_ data: Data, forKey key: String, expectedRevision: UUID?, newRevision: UUID) throws -> Bool {
    try resolve().compareAndSwap(data, forKey: key, expectedRevision: expectedRevision, newRevision: newRevision)
  }

  func deleteItem(forKey key: String) throws {
    try resolve().deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try resolve().hasItem(forKey: key)
  }
}

/// Identity and private-state routing are selected together, only after their marker is readable.
final class KeychainStorageLayout: @unchecked Sendable {
  struct Selection {
    let identity: any KeychainStorage
    let identityService: String
    let appLocal: any KeychainStorage
    let identityIsInAccessGroup: Bool
    let sharedIsAccessible: Bool
  }

  private let lock = NSLock()
  private var selection: Selection?
  private let resolve: @Sendable () throws -> Selection

  init(resolve: @escaping @Sendable () throws -> Selection) {
    self.resolve = resolve
  }

  var resolved: Selection? {
    lock.withLock { selection }
  }

  func get() throws -> Selection {
    try lock.withLock {
      if let selection { return selection }
      let selected = try resolve()
      selection = selected
      return selected
    }
  }
}
