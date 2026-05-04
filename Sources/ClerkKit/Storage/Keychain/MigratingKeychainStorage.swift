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
