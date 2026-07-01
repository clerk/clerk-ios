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
    #expect(decoded.client?.id == "client-1")
    #expect(decoded.client?.signIn?.id == "sign-in-1")
    #expect(decoded.client?.lastActiveSessionId == "session-1")
    #expect(decoded.clientServerFetchDate == serverFetchDate)
    #expect(decoded.environment == .mock)
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
  func legacySignedOutPhonePayloadClearsLocalClient() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let serverFetchDate = Date(timeIntervalSince1970: 200)
    clerk.applyResponseClient(
      client(id: "client-local", signInId: "sign-in-local", updatedAt: 4000, lastActiveSessionId: "session-local"),
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 100)
    )

    let payload = try #require(WatchSyncPayload(applicationContext: [
      "clerkDeviceToken": "phone-token",
      "clerkClientServerFetchDate": serverFetchDate.timeIntervalSince1970,
    ]))

    apply(payload, from: .phone, to: clerk, keychain: keychain)

    #expect(clerk.client == nil)
    #expect(clerk.lastClientServerFetchDate == serverFetchDate)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
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

    apply(payload, from: .phone, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == "client-phone")
    #expect(clerk.client?.signIn?.id == "sign-in-phone")
    #expect(clerk.environment == .mock)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
    #expect(try keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenSynced.rawValue) == "true")
  }

  @Test
  func remoteDeviceTokenSetFencesStaleClientResponses() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("old-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    let staleGeneration = clerk.clientResponseGeneration
    let staleClient = client(id: "client-stale", signInId: "sign-in-stale", updatedAt: 5000, lastActiveSessionId: "session-stale")
    let payloadClient = client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 3000, lastActiveSessionId: "session-phone")

    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(token: "phone-token", version: WatchSyncVersion(rawValue: 1)),
      clientUpdate: .snapshot(
        client: payloadClient,
        serverFetchDate: Date(timeIntervalSince1970: 100),
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )

    apply(payload, from: .phone, to: clerk, keychain: keychain)
    clerk.applyResponseClient(
      staleClient,
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 200),
      clientResponseGeneration: staleGeneration
    )

    #expect(clerk.client?.id == payloadClient.id)
    #expect(clerk.client?.signIn?.id == payloadClient.signIn?.id)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
  }

  @Test
  func cachedClientHydrationDoesNotAdvanceWatchAuthVersion() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let cachedClient = client(id: "client-cached", signInId: "sign-in-cached", updatedAt: 3000)
    try keychain.set(JSONEncoder.clerkEncoder.encode(cachedClient), forKey: ClerkKeychainKey.cachedClient.rawValue)
    try keychain.set("100", forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)

    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: .current(clerkProvider: { clerk })),
      keychain: keychain,
      clientService: MockClientService(get: { nil })
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(watchConnectivityEnabled: true)
    )

    clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }

    #expect(clerk.client?.id == cachedClient.id)
    #expect(try keychain.string(forKey: ClerkKeychainKey.watchSyncAuthState.rawValue) == nil)
    #expect(try keychain.string(forKey: ClerkKeychainKey.watchSyncAuthVersion.rawValue) == nil)
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

    apply(payload, from: .watch, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == "client-local")
    #expect(clerk.client?.signIn?.id == "sign-in-local")
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
    #expect(try keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenSynced.rawValue) == "true")
  }

  @Test
  func watchDeviceTokenSetDoesNotClearPhoneAuthBeforeClientReduction() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let phoneServerDate = Date(timeIntervalSince1970: 200)
    let originalGeneration = clerk.clientResponseGeneration
    let phoneClient = client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 4000, lastActiveSessionId: "session-phone")
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 3000, lastActiveSessionId: "session-watch")
    clerk.applyResponseClient(
      phoneClient,
      responseSequence: 10,
      serverDate: phoneServerDate
    )

    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(token: "watch-token", version: WatchSyncVersion(rawValue: 1)),
      clientUpdate: .snapshot(
        client: watchClient,
        serverFetchDate: Date(timeIntervalSince1970: 100),
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )

    apply(payload, from: .watch, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == phoneClient.id)
    #expect(clerk.client?.signIn?.id == phoneClient.signIn?.id)
    #expect(clerk.lastClientServerFetchDate == phoneServerDate)
    #expect(clerk.clientResponseGeneration == originalGeneration)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == nil)
    #expect(try keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenSynced.rawValue) == "true")
  }

  @Test
  func acceptedWatchClientSnapshotCarriesMatchingDeviceToken() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let phoneServerDate = Date(timeIntervalSince1970: 200)
    let watchServerDate = Date(timeIntervalSince1970: 300)
    let originalGeneration = clerk.clientResponseGeneration
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 4000, lastActiveSessionId: "session-watch")
    clerk.client = nil
    clerk.lastClientServerFetchDate = phoneServerDate

    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(token: "watch-token", version: WatchSyncVersion(rawValue: 1)),
      clientUpdate: .snapshot(
        client: watchClient,
        serverFetchDate: watchServerDate,
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )

    apply(payload, from: .watch, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == watchClient.id)
    #expect(clerk.client?.signIn?.id == watchClient.signIn?.id)
    #expect(clerk.lastClientServerFetchDate == watchServerDate)
    #expect(clerk.clientResponseGeneration != originalGeneration)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "watch-token")
    #expect(try keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenState.rawValue) == "set")
    #expect(try keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenVersion.rawValue) == "1")
  }

  @Test
  func staleWatchClientSnapshotDoesNotCarryDeviceToken() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let phoneServerDate = Date(timeIntervalSince1970: 200)
    let originalGeneration = clerk.clientResponseGeneration
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 4000, lastActiveSessionId: "session-watch")
    clerk.client = nil
    clerk.lastClientServerFetchDate = phoneServerDate

    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(token: "watch-token", version: WatchSyncVersion(rawValue: 1)),
      clientUpdate: .snapshot(
        client: watchClient,
        serverFetchDate: Date(timeIntervalSince1970: 100),
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )

    apply(payload, from: .watch, to: clerk, keychain: keychain)

    #expect(clerk.client == nil)
    #expect(clerk.lastClientServerFetchDate == phoneServerDate)
    #expect(clerk.clientResponseGeneration == originalGeneration)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == nil)
    #expect(try keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenSynced.rawValue) == "true")
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

    apply(payload, from: .watch, to: clerk, keychain: keychain)

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

    apply(payload, from: .watch, to: clerk, keychain: keychain)

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

    apply(payload, from: .watch, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == "client-watch")
    #expect(clerk.client?.signIn?.id == "sign-in-watch")
  }

  @Test
  func payloadWithoutDeviceTokenUpdateDoesNotClearStoredToken() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("local-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)

    let payload = WatchSyncPayload(
      deviceTokenUpdate: .notIncluded,
      clientUpdate: .snapshot(
        client: client(id: "client-watch", updatedAt: 3000),
        serverFetchDate: Date(timeIntervalSince1970: 100),
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )

    apply(payload, from: .watch, to: clerk, keychain: keychain)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "local-token")
  }

  @Test
  func explicitDeviceTokenClearWinsOverStaleSet() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()

    let clearPayload = WatchSyncPayload(
      deviceTokenUpdate: .tokenCleared(version: WatchSyncVersion(rawValue: 3)),
      clientUpdate: .notIncluded,
      environment: nil
    )
    apply(clearPayload, from: .phone, to: clerk, keychain: keychain)

    let stalePayload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(token: "stale-token", version: WatchSyncVersion(rawValue: 2)),
      clientUpdate: .notIncluded,
      environment: nil
    )
    apply(stalePayload, from: .phone, to: clerk, keychain: keychain)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == nil)
    #expect(try keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenState.rawValue) == "cleared")
    #expect(try keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenVersion.rawValue) == "3")
  }

  @Test
  func explicitDeviceTokenClearWinsOverSameVersionNonAuthoritativeSet() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()

    let clearPayload = WatchSyncPayload(
      deviceTokenUpdate: .tokenCleared(version: WatchSyncVersion(rawValue: 3)),
      clientUpdate: .notIncluded,
      environment: nil
    )
    apply(clearPayload, from: .phone, to: clerk, keychain: keychain)

    let sameVersionPayload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(token: "stale-token", version: WatchSyncVersion(rawValue: 3)),
      clientUpdate: .notIncluded,
      environment: nil
    )
    apply(sameVersionPayload, from: .watch, to: clerk, keychain: keychain)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == nil)
    #expect(try keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenState.rawValue) == "cleared")
    #expect(try keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenVersion.rawValue) == "3")
  }

  @Test
  func explicitDeviceTokenClearWinsOverLegacyNonAuthoritativeSet() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()

    let clearPayload = WatchSyncPayload(
      deviceTokenUpdate: .tokenCleared(version: WatchSyncVersion(rawValue: 3)),
      clientUpdate: .notIncluded,
      environment: nil
    )
    apply(clearPayload, from: .phone, to: clerk, keychain: keychain)

    let legacyPayload = WatchSyncPayload(
      deviceToken: "stale-token",
      client: nil,
      clientServerFetchDate: nil,
      environment: nil
    )
    apply(legacyPayload, from: .watch, to: clerk, keychain: keychain)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == nil)
    #expect(try keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenState.rawValue) == "cleared")
    #expect(try keychain.string(forKey: ClerkKeychainKey.watchSyncDeviceTokenVersion.rawValue) == "3")
  }

  @Test
  func staleAuthSnapshotDoesNotUndoNewerExplicitClear() {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()

    let clearPayload = WatchSyncPayload(
      deviceTokenUpdate: .notIncluded,
      clientUpdate: .cleared(
        serverFetchDate: Date(timeIntervalSince1970: 200),
        version: WatchSyncVersion(rawValue: 3)
      ),
      environment: nil
    )
    apply(clearPayload, from: .phone, to: clerk, keychain: keychain)

    let stalePayload = WatchSyncPayload(
      deviceTokenUpdate: .notIncluded,
      clientUpdate: .snapshot(
        client: client(id: "client-stale", updatedAt: 4000),
        serverFetchDate: Date(timeIntervalSince1970: 300),
        version: WatchSyncVersion(rawValue: 2)
      ),
      environment: nil
    )
    apply(stalePayload, from: .phone, to: clerk, keychain: keychain)

    #expect(clerk.client == nil)
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 200))
  }

  @Test
  func legacyAuthSnapshotDoesNotUndoVersionedExplicitClear() {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()

    let clearPayload = WatchSyncPayload(
      deviceTokenUpdate: .notIncluded,
      clientUpdate: .cleared(
        serverFetchDate: Date(timeIntervalSince1970: 200),
        version: WatchSyncVersion(rawValue: 3)
      ),
      environment: nil
    )
    apply(clearPayload, from: .phone, to: clerk, keychain: keychain)

    let legacyPayload = WatchSyncPayload(
      deviceToken: nil,
      client: client(id: "client-legacy", updatedAt: 4000),
      clientServerFetchDate: Date(timeIntervalSince1970: 300),
      environment: nil
    )
    apply(legacyPayload, from: .phone, to: clerk, keychain: keychain)

    #expect(clerk.client == nil)
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 200))
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

  private func apply(
    _ payload: WatchSyncPayload,
    from source: WatchSyncSource,
    to clerk: Clerk,
    keychain: InMemoryKeychain
  ) {
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    WatchConnectivityCoordinator().apply(payload, from: source, to: clerk)
  }
}
