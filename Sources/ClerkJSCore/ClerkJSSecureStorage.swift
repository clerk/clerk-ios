import Foundation

public struct ClerkJSSecureStorage: Sendable {
  public var read: @Sendable (String) async throws -> String?
  public var write: @Sendable (String, String?) async throws -> Void
  public var compareAndSwap: @Sendable (String, String?, String?) async throws -> Bool

  public init(
    read: @escaping @Sendable (String) async throws -> String?,
    write: @escaping @Sendable (String, String?) async throws -> Void,
    compareAndSwap: @escaping @Sendable (String, String?, String?) async throws -> Bool
  ) {
    self.read = read
    self.write = write
    self.compareAndSwap = compareAndSwap
  }

  public static func memory() -> ClerkJSSecureStorage {
    let storage = SecureStorageBox()
    return .init(
      read: { try await storage.read($0) },
      write: { try await storage.write($0, $1) },
      compareAndSwap: { try await storage.compareAndSwap($0, $1, $2) }
    )
  }

  public static func keychain(service: String) -> ClerkJSSecureStorage {
    let storage = SecureStorageBox(keychain: ClerkJSKeychain(service: service))
    return .init(
      read: { try await storage.read($0) },
      write: { try await storage.write($0, $1) },
      compareAndSwap: { try await storage.compareAndSwap($0, $1, $2) }
    )
  }
}

private actor SecureStorageBox {
  let keychain: ClerkJSKeychain?
  var values: [String: String] = [:]

  init(keychain: ClerkJSKeychain? = nil) {
    self.keychain = keychain
  }

  func read(_ key: String) throws -> String? {
    guard let keychain else { return values[key] }
    return try keychain.data(account: key).map { String(decoding: $0, as: UTF8.self) }
  }

  func write(_ key: String, _ value: String?) throws {
    if let keychain {
      if let value { try keychain.set(Data(value.utf8), account: key) }
      else { try keychain.delete(account: key) }
    } else {
      values[key] = value
    }
  }

  func compareAndSwap(_ key: String, _ expected: String?, _ replacement: String?) throws -> Bool {
    guard try read(key) == expected else { return false }
    try write(key, replacement)
    return true
  }
}
