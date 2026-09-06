@testable import ClerkJSCore
import Foundation
import Testing

struct ClerkJSCacheTests {
  @Test
  func memoryTokenCacheRoundTrip() async {
    let cache = ClerkJSTokenCache.memory()
    #expect(await cache.getToken() == "")
    await cache.saveToken("client-jwt")
    #expect(await cache.getToken() == "client-jwt")
    await cache.saveToken("")
    #expect(await cache.getToken() == "")
  }

  @Test
  func memoryResourceCacheReturnsNullsWhenEmpty() async {
    let cache = ClerkJSResourceCache.memory()
    let empty = await cache.load()
    #expect(empty.client == nil)
    #expect(empty.environment == nil)
  }

  @Test
  func memoryResourceCacheRoundTrip() async throws {
    let cache = ClerkJSResourceCache.memory()
    let client = try #require(#"{"object":"client","id":"client_mem"}"#.data(using: .utf8))
    let environment = try #require(#"{"object":"environment"}"#.data(using: .utf8))
    await cache.save(ClerkJSCachedResources(client: client, environment: environment))
    let loaded = await cache.load()
    #expect(loaded.client == client)
    #expect(loaded.environment == environment)
  }

  @Test
  func keychainTokenCacheRoundTrip() async throws {
    let keychain = ClerkJSKeychain(service: testKeychainService)
    let account = "token.\(UUID().uuidString)"
    guard try keychainIsAvailable(keychain, account: account) else {
      return
    }
    defer { try? keychain.delete(account: account) }

    let cache = ClerkJSTokenCache.keychain(service: testKeychainService, account: account)
    await cache.saveToken("client-jwt")
    #expect(await cache.getToken() == "client-jwt")
    await cache.saveToken("")
    #expect(await cache.getToken() == "")
  }

  @Test
  func keychainResourceCacheRoundTrip() async throws {
    let keychain = ClerkJSKeychain(service: testKeychainService)
    let clientAccount = "client.\(UUID().uuidString)"
    let environmentAccount = "environment.\(UUID().uuidString)"
    guard try keychainIsAvailable(keychain, account: clientAccount) else {
      return
    }
    defer {
      try? keychain.delete(account: clientAccount)
      try? keychain.delete(account: environmentAccount)
    }

    let cache = ClerkJSResourceCache.keychain(
      service: testKeychainService,
      clientAccount: clientAccount,
      environmentAccount: environmentAccount
    )
    let empty = await cache.load()
    #expect(empty.client == nil)
    #expect(empty.environment == nil)

    let client = try #require(#"{"object":"client","id":"client_kc"}"#.data(using: .utf8))
    let environment = try #require(#"{"object":"environment"}"#.data(using: .utf8))
    await cache.save(ClerkJSCachedResources(client: client, environment: environment))
    let loaded = await cache.load()
    #expect(loaded.client == client)
    #expect(loaded.environment == environment)
  }
}

private let testKeychainService = "com.clerk.jscore.tests"

private func keychainIsAvailable(_ keychain: ClerkJSKeychain, account: String) throws -> Bool {
  do {
    try keychain.set(Data("probe".utf8), account: account)
    try keychain.delete(account: account)
    return true
  } catch let error as ClerkJSKeychainError where error.isMissingEntitlement {
    Issue.record("Skipped Keychain round-trip: missing entitlement", severity: .warning)
    return false
  }
}
