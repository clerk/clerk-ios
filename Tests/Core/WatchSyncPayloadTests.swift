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
  func clerkSnapshotBroadcastsExplicitPendingDeviceTokenClear() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("true", forKey: ClerkKeychainKey.clerkDeviceTokenClearPending.rawValue)

    let payload = WatchSyncPayload(clerk: clerk, keychain: keychain)

    #expect(payload.deviceToken == nil)
    #expect(payload.clearsDeviceToken == true)
    #expect(payload.applicationContext["clerkDeviceTokenCleared"] as? Bool == true)
  }

  @Test
  func clerkSnapshotDoesNotTreatStoredDeviceTokenAsClearWhenClearIsPending() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("device-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try keychain.set("true", forKey: ClerkKeychainKey.clerkDeviceTokenClearPending.rawValue)

    let payload = WatchSyncPayload(clerk: clerk, keychain: keychain)

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
  func phonePayloadClearsDeviceTokenOnWatch() throws {
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

    payload.apply(from: .phone, to: clerk, keychain: keychain)

    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == false)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceTokenSynced.rawValue) == "true")
  }

  @Test
  func peerDeviceTokenClearClearsPendingLocalClear() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("watch-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try keychain.set("true", forKey: ClerkKeychainKey.clerkDeviceTokenClearPending.rawValue)

    let payload = WatchSyncPayload(
      deviceToken: nil,
      clearsDeviceToken: true,
      client: nil,
      clientServerFetchDate: nil,
      environment: nil
    )

    payload.apply(from: .phone, to: clerk, keychain: keychain)

    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == false)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceTokenClearPending.rawValue) == false)
  }

  @Test
  func watchPayloadClearDoesNotWinFirstDeviceTokenSync() throws {
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

    payload.apply(from: .watch, to: clerk, keychain: keychain)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceTokenSynced.rawValue) == "true")
  }

  @Test
  func watchPayloadClearDoesNotWinFirstClientSyncWhenDeviceTokenIsMissing() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let localClient = client(id: "client-local", signInId: "sign-in-local", updatedAt: 4000, lastActiveSessionId: "session-local")
    let serverFetchDate = Date(timeIntervalSince1970: 200)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      clientService: MockClientService(get: { localClient })
    )
    clerk.applyResponseClient(
      localClient,
      responseSequence: 10,
      serverDate: serverFetchDate
    )

    let payload = WatchSyncPayload(
      deviceToken: nil,
      clearsDeviceToken: true,
      client: nil,
      clientServerFetchDate: nil,
      environment: nil
    )

    payload.apply(from: .watch, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == "client-local")
    #expect(clerk.lastClientServerFetchDate == serverFetchDate)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceTokenSynced.rawValue) == "true")
  }

  @Test
  func applyingDeviceTokenClearsPendingDeviceTokenClear() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("true", forKey: ClerkKeychainKey.clerkDeviceTokenClearPending.rawValue)

    let payload = WatchSyncPayload(
      deviceToken: "phone-token",
      client: nil,
      clientServerFetchDate: nil,
      environment: nil
    )

    payload.apply(from: .phone, to: clerk, keychain: keychain)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceTokenClearPending.rawValue) == false)
  }

  @Test
  func watchPayloadDeviceTokenDoesNotCancelPendingLocalClear() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("true", forKey: ClerkKeychainKey.clerkDeviceTokenClearPending.rawValue)

    let payload = WatchSyncPayload(
      deviceToken: "stale-watch-token",
      client: nil,
      clientServerFetchDate: nil,
      environment: nil
    )

    payload.apply(from: .watch, to: clerk, keychain: keychain)

    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == false)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceTokenClearPending.rawValue) == "true")
  }

  @Test
  func watchPayloadDeviceTokenDoesNotApplyClientWhileLocalClearIsPending() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("true", forKey: ClerkKeychainKey.clerkDeviceTokenClearPending.rawValue)

    let payload = WatchSyncPayload(
      deviceToken: "stale-watch-token",
      client: client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 3000, lastActiveSessionId: "session-watch"),
      clientServerFetchDate: Date(timeIntervalSince1970: 100),
      environment: nil
    )

    payload.apply(from: .watch, to: clerk, keychain: keychain)

    #expect(clerk.client == nil)
    #expect(clerk.lastClientServerFetchDate == nil)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == false)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceTokenClearPending.rawValue) == "true")
  }

  @Test
  func peerDeviceTokenClearInvalidatesCachedClientStateAndStaleGeneration() throws {
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

    let payload = WatchSyncPayload(
      deviceToken: nil,
      clearsDeviceToken: true,
      client: nil,
      clientServerFetchDate: nil,
      environment: nil
    )

    payload.apply(from: .phone, to: clerk, keychain: keychain)
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
  }

  @Test
  func phonePayloadAppliesAuthoritativeClientAndWinsFirstDeviceTokenSync() throws {
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

    payload.apply(from: .phone, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == "client-phone")
    #expect(clerk.client?.signIn?.id == "sign-in-phone")
    #expect(clerk.environment == .mock)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceTokenSynced.rawValue) == "true")
  }

  @Test
  func watchPayloadDoesNotRollBackNewerLocalStateOrFirstSyncDeviceToken() throws {
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

    payload.apply(from: .watch, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == "client-local")
    #expect(clerk.client?.signIn?.id == "sign-in-local")
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceTokenSynced.rawValue) == "true")
  }

  @Test
  func watchPayloadSeedsPhoneWhenNoLocalClient() {
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

    payload.apply(from: .watch, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == "client-watch")
    #expect(clerk.client?.signIn?.id == "sign-in-watch")
    #expect(clerk.environment == .mock)
    #expect(clerk.lastClientServerFetchDate == watchServerDate)
  }

  @Test
  func watchPayloadNilClientDoesNotClearPhoneClient() {
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

    payload.apply(from: .watch, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == "client-local")
  }

  @Test
  func watchPayloadWithNewerServerFetchDateUpdatesPhoneClient() {
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

    payload.apply(from: .watch, to: clerk, keychain: keychain)

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
