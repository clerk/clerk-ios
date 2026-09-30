@testable import ClerkKit
import Foundation
import Testing

struct ClerkIdentityStoreTests {
  private let keychain = InMemoryKeychain()
  private let clientKeychain = InMemoryKeychain()

  private var store: ClerkIdentityStore {
    ClerkIdentityStore(keychain: keychain, clientKeychain: clientKeychain)
  }

  @Test
  func savesAndLoadsTheTokenWithItsClient() throws {
    try store.save(ClerkIdentitySnapshot(state: .present, deviceToken: "token", client: .mock, serverDate: Date(timeIntervalSince1970: 100)))

    let identity = try #require(try store.load())
    #expect(identity.deviceToken == "token")
    #expect(identity.client?.id == Client.mock.id)
    #expect(identity.serverDate == Date(timeIntervalSince1970: 100))
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "token")
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedClient.rawValue) == false)
    #expect(try clientKeychain.hasItem(forKey: ClerkKeychainKey.cachedClient.rawValue))
  }

  @Test
  func ignoresAClientCachedForAnotherToken() throws {
    try store.save(ClerkIdentitySnapshot(state: .present, deviceToken: "token", client: .mock, serverDate: nil))
    // Another app sharing the access group replaced the token.
    try keychain.set("other-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)

    let identity = try #require(try store.load())
    #expect(identity.deviceToken == "other-token")
    #expect(identity.client == nil)
  }

  @Test
  func readsAClientCachedByAnEarlierSDK() throws {
    try keychain.set("token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try clientKeychain.set(JSONEncoder.clerkEncoder.encode(Client.mock), forKey: ClerkKeychainKey.cachedClient.rawValue)

    let identity = try #require(try store.load())
    #expect(identity.deviceToken == "token")
    #expect(identity.client?.id == Client.mock.id)
  }

  @Test
  func savingWithoutATokenDeletesTheTokenAndClient() throws {
    try store.save(ClerkIdentitySnapshot(state: .present, deviceToken: "token", client: .mock, serverDate: nil))

    try store.save(.signedOut)

    #expect(try store.load() == nil)
    #expect(try clientKeychain.hasItem(forKey: ClerkKeychainKey.cachedClient.rawValue) == false)
  }
}
