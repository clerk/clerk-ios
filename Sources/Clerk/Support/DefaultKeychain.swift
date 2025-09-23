import Foundation
import SimpleKeychain

struct DefaultKeychain: KeychainStore {
  private let keychain: SimpleKeychain

  init(simpleKeychain: SimpleKeychain) {
    self.keychain = simpleKeychain
  }

  func set(_ data: Data, forKey key: String) throws {
    try keychain.set(data, forKey: key)
  }

  func set(_ string: String, forKey key: String) throws {
    try keychain.set(string, forKey: key)
  }

 func data(forKey key: String) throws -> Data? {
    return try? keychain.data(forKey: key)
  }

  func string(forKey key: String) throws -> String? {
    return try? keychain.string(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    try keychain.deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    return try keychain.hasItem(forKey: key)
  }
}
