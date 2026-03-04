@testable import ClerkKit
import Foundation
import Testing

struct ClientPersistenceWorkerTests {
  @Test
  func ignoresStalePersistenceSequence() async throws {
    let keychain = InMemoryKeychain()
    let worker = ClientPersistenceWorker()

    var newerClient = Client.mock
    newerClient.updatedAt = Date(timeIntervalSince1970: 200)
    newerClient.lastActiveSessionId = "newer-session"

    var olderClient = Client.mock
    olderClient.updatedAt = Date(timeIntervalSince1970: 100)
    olderClient.lastActiveSessionId = "older-session"

    await worker.persist(client: newerClient, sequence: 2, keychain: keychain)
    await worker.persist(client: olderClient, sequence: 1, keychain: keychain)

    let cachedClientData = try #require(try keychain.data(forKey: ClerkKeychainKey.cachedClient.rawValue))
    let cachedClient = try JSONDecoder.clerkDecoder.decode(Client.self, from: cachedClientData)
    #expect(cachedClient.lastActiveSessionId == newerClient.lastActiveSessionId)
    #expect(cachedClient.updatedAt == newerClient.updatedAt)
  }

  @Test
  func clearsCacheForLatestNilMutation() async throws {
    let keychain = InMemoryKeychain()
    let worker = ClientPersistenceWorker()

    await worker.persist(client: .mock, sequence: 1, keychain: keychain)
    await worker.persist(client: nil, sequence: 2, keychain: keychain)

    #expect(try keychain.data(forKey: ClerkKeychainKey.cachedClient.rawValue) == nil)
  }
}
