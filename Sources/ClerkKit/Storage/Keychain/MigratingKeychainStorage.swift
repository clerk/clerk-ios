import Foundation

struct MigratingKeychainStorage: KeychainStorage {
  let primary: any KeychainStorage
  let fallbacks: [any KeychainStorage]

  init(primary: any KeychainStorage, fallbacks: [any KeychainStorage]) {
    self.primary = primary
    self.fallbacks = fallbacks
  }

  init(primary: any KeychainStorage, fallback: any KeychainStorage) {
    self.init(primary: primary, fallbacks: [fallback])
  }

  func set(_ data: Data, forKey key: String) throws {
    try primary.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    if let data = try primary.data(forKey: key) {
      return data
    }

    for fallback in fallbacks {
      guard let fallbackData = try fallback.data(forKey: key) else {
        continue
      }

      try? primary.set(fallbackData, forKey: key)
      return fallbackData
    }

    return nil
  }

  func deleteItem(forKey key: String) throws {
    var deletionError: Error?

    for storage in [primary] + fallbacks {
      do {
        try storage.deleteItem(forKey: key)
      } catch {
        deletionError = deletionError ?? error
      }
    }

    if let deletionError {
      throw deletionError
    }
  }

  func hasItem(forKey key: String) throws -> Bool {
    try ([primary] + fallbacks).contains { try $0.hasItem(forKey: key) }
  }
}
