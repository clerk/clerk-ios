@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct WatchSyncPayloadTests {
  @Test
  func applicationContextRoundTripsPayloadValues() throws {
    let serverFetchDate = Date(timeIntervalSince1970: 123)
    let payload = WatchSyncPayload(
      deviceToken: "device-token",
      client: client(id: "client-1", signInId: "sign-in-1", updatedAt: 2000, lastActiveSessionId: "session-1"),
      clientServerFetchDate: serverFetchDate,
      environment: .mock
    )

    let decoded = try #require(WatchSyncPayload(applicationContext: payload.applicationContext))

    #expect(decoded.deviceToken == "device-token")
    #expect(decoded.clearsDeviceToken == false)
    #expect(decoded.client?.id == "client-1")
    #expect(decoded.client?.signIn?.id == "sign-in-1")
    #expect(decoded.client?.lastActiveSessionId == "session-1")
    #expect(decoded.clientServerFetchDate == serverFetchDate)
    #expect(decoded.environment == .mock)
  }

  @Test
  func applicationContextRoundTripsExplicitDeviceTokenClear() throws {
    let payload = WatchSyncPayload(
      deviceToken: nil,
      clearsDeviceToken: true,
      client: nil,
      clientServerFetchDate: nil,
      environment: nil
    )

    let decoded = try #require(WatchSyncPayload(applicationContext: payload.applicationContext))

    #expect(payload.applicationContext["clerkDeviceToken"] == nil)
    #expect(payload.applicationContext["clerkDeviceTokenCleared"] as? Bool == true)
    #expect(decoded.deviceToken == nil)
    #expect(decoded.clearsDeviceToken == true)
  }

  @Test
  func clerkSnapshotDoesNotBroadcastMissingDeviceTokenAsExplicitClear() {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()

    let payload = WatchSyncPayload(clerk: clerk, keychain: keychain)

    #expect(payload.deviceToken == nil)
    #expect(payload.clearsDeviceToken == false)
    #expect(payload.applicationContext["clerkDeviceTokenCleared"] == nil)
  }

  @Test
  func clerkSnapshotCanBroadcastMissingDeviceTokenAsExplicitClear() {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain
    )
    clerk.markDeviceTokenClearPendingForWatchSync()

    let payload = WatchSyncPayload(
      clerk: clerk,
      keychain: keychain,
      clearsMissingDeviceToken: clerk.deviceTokenClearIsPendingForWatchSync()
    )

    #expect(payload.deviceToken == nil)
    #expect(payload.clearsDeviceToken == true)
    #expect(payload.applicationContext["clerkDeviceTokenCleared"] as? Bool == true)
  }

  @Test
  func clerkSnapshotDoesNotTreatStoredDeviceTokenAsClear() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain
    )
    clerk.markDeviceTokenClearPendingForWatchSync()
    try keychain.set("device-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)

    let payload = WatchSyncPayload(
      clerk: clerk,
      keychain: keychain,
      clearsMissingDeviceToken: clerk.deviceTokenClearIsPendingForWatchSync()
    )

    #expect(payload.deviceToken == "device-token")
    #expect(payload.clearsDeviceToken == false)
    #expect(payload.applicationContext["clerkDeviceToken"] as? String == "device-token")
    #expect(payload.applicationContext["clerkDeviceTokenCleared"] == nil)
  }

  @Test
  func applicationContextOmitsClientWhenNil() {
    let payload = WatchSyncPayload(
      deviceToken: "device-token",
      client: nil,
      clientServerFetchDate: Date(timeIntervalSince1970: 1),
      environment: nil
    )

    #expect(payload.applicationContext["clerkClient"] == nil)
  }

  @Test
  func phonePayloadClearsDeviceTokenOnWatch() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("watch-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)

    let payload = WatchSyncPayload(
      deviceToken: nil,
      clearsDeviceToken: true,
      client: nil,
      clientServerFetchDate: nil,
      environment: nil
    )

    await payload.apply(from: .phone, to: clerk, keychain: keychain)

    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == false)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceTokenSynced.rawValue) == "true")
  }

  @Test
  func watchPayloadClearDoesNotClearPhoneDeviceToken() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("phone-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)

    let payload = WatchSyncPayload(
      deviceToken: nil,
      clearsDeviceToken: true,
      client: nil,
      clientServerFetchDate: nil,
      environment: nil
    )

    await payload.apply(from: .watch, to: clerk, keychain: keychain)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceTokenSynced.rawValue) == false)
  }

  @Test
  func watchPayloadDoesNotRestorePhoneWhileDeviceTokenClearIsPending() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain
    )
    clerk.markDeviceTokenClearPendingForWatchSync()

    let payload = WatchSyncPayload(
      deviceToken: "watch-token",
      client: client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 3000, lastActiveSessionId: "session-watch"),
      clientServerFetchDate: Date(timeIntervalSince1970: 200),
      environment: .mock
    )

    await payload.apply(from: .watch, to: clerk, keychain: keychain)

    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == false)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceTokenClearPending.rawValue) == "true")
    #expect(clerk.client == nil)
    #expect(clerk.environment == nil)
  }

  @Test
  func peerDeviceTokenClearInvalidatesCachedClientStateAndStaleGeneration() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("watch-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try keychain.set(#require("cached-client".data(using: .utf8)), forKey: ClerkKeychainKey.cachedClient.rawValue)
    try keychain.set("cached-date", forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)
    try keychain.set(#require("cached-environment".data(using: .utf8)), forKey: ClerkKeychainKey.cachedEnvironment.rawValue)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain
    )
    clerk.applyResponseClient(
      client(id: "client-local", signInId: "sign-in-local", updatedAt: 4000, lastActiveSessionId: "session-local"),
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let staleGeneration = clerk.clientResponseGeneration
    let tokenCacheKey = Session.mock.tokenCacheKey(template: nil)
    await SessionTokensCache.shared.insertToken(.init(jwt: "cached-jwt"), cacheKey: tokenCacheKey)

    let payload = WatchSyncPayload(
      deviceToken: nil,
      clearsDeviceToken: true,
      client: nil,
      clientServerFetchDate: nil,
      environment: nil
    )

    await payload.apply(from: .phone, to: clerk, keychain: keychain)
    clerk.applyResponseClient(
      client(id: "client-stale", signInId: "sign-in-stale", updatedAt: 5000, lastActiveSessionId: "session-stale"),
      responseSequence: 2,
      serverDate: Date(timeIntervalSince1970: 200),
      clientResponseGeneration: staleGeneration
    )

    #expect(clerk.client == nil)
    #expect(clerk.clientResponseGeneration != staleGeneration)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == false)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedClient.rawValue) == false)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedClientServerDate.rawValue) == false)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedEnvironment.rawValue) == false)
    #expect(await SessionTokensCache.shared.getToken(cacheKey: tokenCacheKey) == nil)
  }

  @Test
  func phonePayloadAppliesAuthoritativeClientAndWinsFirstDeviceTokenSync() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("watch-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    clerk.applyResponseClient(
      client(id: "client-local", signInId: "sign-in-local", updatedAt: 4000, lastActiveSessionId: "session-local"),
      responseSequence: 10
    )

    let payload = WatchSyncPayload(
      deviceToken: "phone-token",
      client: client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 3000, lastActiveSessionId: "session-phone"),
      clientServerFetchDate: Date(timeIntervalSince1970: 100),
      environment: .mock
    )

    await payload.apply(from: .phone, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == "client-phone")
    #expect(clerk.client?.signIn?.id == "sign-in-phone")
    #expect(clerk.environment == .mock)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceTokenSynced.rawValue) == "true")
  }

  @Test
  func watchPayloadDoesNotRollBackNewerLocalStateOrFirstSyncDeviceToken() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("phone-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    clerk.applyResponseClient(
      client(id: "client-local", signInId: "sign-in-local", updatedAt: 4000, lastActiveSessionId: "session-local"),
      responseSequence: 10,
      serverDate: Date(timeIntervalSince1970: 200)
    )

    let payload = WatchSyncPayload(
      deviceToken: "watch-token",
      client: client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 3000, lastActiveSessionId: "session-watch"),
      clientServerFetchDate: Date(timeIntervalSince1970: 100),
      environment: nil
    )

    await payload.apply(from: .watch, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == "client-local")
    #expect(clerk.client?.signIn?.id == "sign-in-local")
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceTokenSynced.rawValue) == "true")
  }

  @Test
  func watchPayloadSeedsPhoneWhenNoLocalClient() async {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    clerk.client = nil
    let watchServerDate = Date(timeIntervalSince1970: 100)

    let payload = WatchSyncPayload(
      deviceToken: nil,
      client: client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 3000, lastActiveSessionId: "session-watch"),
      clientServerFetchDate: watchServerDate,
      environment: .mock
    )

    await payload.apply(from: .watch, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == "client-watch")
    #expect(clerk.client?.signIn?.id == "sign-in-watch")
    #expect(clerk.environment == .mock)
    #expect(clerk.lastClientServerFetchDate == watchServerDate)
  }

  @Test
  func watchPayloadNilClientDoesNotClearPhoneClient() async {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    clerk.applyResponseClient(
      client(id: "client-local", signInId: "sign-in-local", updatedAt: 4000, lastActiveSessionId: "session-local"),
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 100)
    )

    let payload = WatchSyncPayload(
      deviceToken: nil,
      client: nil,
      clientServerFetchDate: Date(timeIntervalSince1970: 200),
      environment: nil
    )

    await payload.apply(from: .watch, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == "client-local")
  }

  @Test
  func watchPayloadWithNewerServerFetchDateUpdatesPhoneClient() async {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    clerk.applyResponseClient(
      client(id: "client-local", signInId: "sign-in-local", updatedAt: 4000, lastActiveSessionId: "session-local"),
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 100)
    )

    let payload = WatchSyncPayload(
      deviceToken: nil,
      client: client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 3000, lastActiveSessionId: "session-watch"),
      clientServerFetchDate: Date(timeIntervalSince1970: 200),
      environment: nil
    )

    await payload.apply(from: .watch, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == "client-watch")
    #expect(clerk.client?.signIn?.id == "sign-in-watch")
  }

  private func client(id: String, signInId: String? = nil, updatedAt: TimeInterval, lastActiveSessionId: String? = nil) -> Client {
    var client = Client.mockSignedOut
    client.id = id
    client.updatedAt = Date(timeIntervalSince1970: updatedAt)
    client.lastActiveSessionId = lastActiveSessionId
    if let signInId {
      var signIn = SignIn.mock
      signIn.id = signInId
      client.signIn = signIn
    }
    return client
  }
}
