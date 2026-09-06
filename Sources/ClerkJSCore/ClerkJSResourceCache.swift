import Foundation

public struct ClerkJSCachedResources: Sendable, Equatable {
  public var client: Data?
  public var environment: Data?

  public init(client: Data? = nil, environment: Data? = nil) {
    self.client = client
    self.environment = environment
  }
}

public struct ClerkJSResourceCache: Sendable {
  public var load: @Sendable () async -> ClerkJSCachedResources
  public var save: @Sendable (ClerkJSCachedResources) async -> Void

  public init(
    load: @escaping @Sendable () async -> ClerkJSCachedResources,
    save: @escaping @Sendable (ClerkJSCachedResources) async -> Void
  ) {
    self.load = load
    self.save = save
  }

  public static func memory() -> ClerkJSResourceCache {
    let box = MemoryResourceBox()
    return ClerkJSResourceCache(
      load: { await box.load() },
      save: { await box.save($0) }
    )
  }

  public static func keychain(
    service: String,
    clientAccount: String,
    environmentAccount: String
  ) -> ClerkJSResourceCache {
    let box = KeychainResourceBox(
      keychain: ClerkJSKeychain(service: service),
      clientAccount: clientAccount,
      environmentAccount: environmentAccount
    )
    return ClerkJSResourceCache(
      load: { await box.load() },
      save: { await box.save($0) }
    )
  }
}

private actor MemoryResourceBox {
  var resources = ClerkJSCachedResources()

  func load() -> ClerkJSCachedResources {
    resources
  }

  func save(_ resources: ClerkJSCachedResources) {
    self.resources = resources
  }
}

private actor KeychainResourceBox {
  let keychain: ClerkJSKeychain
  let clientAccount: String
  let environmentAccount: String

  init(keychain: ClerkJSKeychain, clientAccount: String, environmentAccount: String) {
    self.keychain = keychain
    self.clientAccount = clientAccount
    self.environmentAccount = environmentAccount
  }

  func load() -> ClerkJSCachedResources {
    ClerkJSCachedResources(
      client: snapshot(account: clientAccount),
      environment: snapshot(account: environmentAccount)
    )
  }

  func save(_ resources: ClerkJSCachedResources) {
    write(resources.client, account: clientAccount)
    write(resources.environment, account: environmentAccount)
  }

  private func snapshot(account: String) -> Data? {
    guard let data = try? keychain.data(account: account), !data.isEmpty else {
      return nil
    }
    guard (try? JSONSerialization.jsonObject(with: data)) != nil else {
      return nil
    }
    return data
  }

  private func write(_ data: Data?, account: String) {
    if let data, !data.isEmpty, (try? JSONSerialization.jsonObject(with: data)) != nil {
      try? keychain.set(data, account: account)
    } else {
      try? keychain.delete(account: account)
    }
  }
}
