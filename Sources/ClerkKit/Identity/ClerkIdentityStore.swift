//
//  ClerkIdentityStore.swift
//  Clerk
//

import Foundation

/// Persists the device token in the configured Keychain, where every app sharing its access group
/// reads and writes it, and caches this app's Client next to the token it belongs to.
struct ClerkIdentityStore {
  private struct CachedClient: Codable {
    let deviceToken: String
    let client: Client
    let serverDate: Date?
  }

  let keychain: any KeychainStorage
  let clientKeychain: any KeychainStorage

  init(keychain: any KeychainStorage, clientKeychain: (any KeychainStorage)? = nil) {
    self.keychain = keychain
    self.clientKeychain = clientKeychain ?? keychain
  }

  func deviceToken() throws -> String? {
    try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue).nilIfEmpty
  }

  func load() throws -> ClerkIdentitySnapshot? {
    guard let token = try deviceToken() else { return nil }
    let cached = try clientKeychain.data(forKey: ClerkKeychainKey.cachedClient.rawValue).flatMap { data in
      if let cached = try? JSONDecoder.clerkDecoder.decode(CachedClient.self, from: data) {
        return cached.deviceToken == token ? cached : nil
      }
      // Earlier SDK versions cached the Client alone, always together with the token.
      return (try? JSONDecoder.clerkDecoder.decode(Client.self, from: data)).map {
        CachedClient(deviceToken: token, client: $0, serverDate: nil)
      }
    }
    return ClerkIdentitySnapshot(
      state: cached == nil ? .cleared : .present,
      deviceToken: token,
      client: cached?.client,
      serverDate: cached?.serverDate
    )
  }

  func save(_ identity: ClerkIdentitySnapshot) throws {
    let identity = try identity.validated()
    try saveDeviceToken(identity.deviceToken)
    try saveClient(identity.client, serverDate: identity.serverDate, for: identity.deviceToken)
  }

  func saveDeviceToken(_ token: String?) throws {
    if let token {
      try keychain.set(token, forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    } else {
      try keychain.deleteItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    }
  }

  func saveClient(_ client: Client?, serverDate: Date?, for token: String?) throws {
    guard let client, let token else {
      try clientKeychain.deleteItem(forKey: ClerkKeychainKey.cachedClient.rawValue)
      return
    }
    try clientKeychain.set(
      JSONEncoder.clerkEncoder.encode(CachedClient(deviceToken: token, client: client, serverDate: serverDate)),
      forKey: ClerkKeychainKey.cachedClient.rawValue
    )
  }

  func delete() throws {
    try saveDeviceToken(nil)
    try saveClient(nil, serverDate: nil, for: nil)
  }
}
