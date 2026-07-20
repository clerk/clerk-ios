@testable import ClerkKit
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct WatchSyncPayloadTests {
  @Test
  func watchVersionAdvancementFailsAtMaximumValue() throws {
    #expect(
      try WatchSyncVersion(rawValue: Int.max - 1).next()
        == WatchSyncVersion(rawValue: Int.max)
    )
    #expect(throws: WatchSyncVersion.Error.exhausted) {
      try WatchSyncVersion(rawValue: Int.max).next()
    }
  }

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
  func outgoingPayloadReadsDeviceTokenVersionFromMetadataRecord() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try WatchSyncMetadataStore(keychain: keychain).save(
      WatchSyncMetadataRecord(
        deviceTokenState: .set,
        deviceTokenVersion: 7,
        authState: nil,
        authVersion: nil
      )
    )
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )

    let payload = try WatchSyncPayload(
      clerk: clerk,
      metadata: WatchSyncMetadataStore(keychain: keychain).load(),
      authGeneration: .initial
    )

    #expect(payload.deviceTokenUpdate.version == WatchSyncVersion(rawValue: 7))
  }

  @Test
  func sharedIdentityChangeUsesOneMetadataSnapshot() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = MetadataReadCountingKeychain()
    try keychain.set("token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try WatchSyncMetadataStore(keychain: keychain).save(
      WatchSyncMetadataRecord(
        deviceTokenState: .set,
        deviceTokenVersion: 7,
        authState: .cleared,
        authVersion: 7
      )
    )
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    let coordinator = WatchConnectivityCoordinator()
    keychain.resetMetadataReadCount()

    try coordinator.handle(.identityDidChange, from: clerk)

    #expect(keychain.metadataReadCount == 1)
  }

  @Test
  func localClientChangeUsesOneMetadataSnapshot() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = MetadataReadCountingKeychain()
    try WatchSyncMetadataStore(keychain: keychain).save(.empty)
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    clerk.client = .mock
    let coordinator = WatchConnectivityCoordinator()
    keychain.resetMetadataReadCount()

    try coordinator.handle(.clientDidChange(previous: nil, current: clerk.client), from: clerk)

    #expect(keychain.metadataReadCount == 1)
  }

  @Test
  func localDeviceTokenChangeUsesOneMetadataSnapshot() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = MetadataReadCountingKeychain()
    try keychain.set("new-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try WatchSyncMetadataStore(keychain: keychain).save(.empty)
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    let coordinator = WatchConnectivityCoordinator()
    keychain.resetMetadataReadCount()

    try coordinator.handle(
      .deviceTokenDidChange(previous: "old-token", current: "new-token"),
      from: clerk
    )

    #expect(keychain.metadataReadCount == 1)
  }

  @Test
  func watchTokenClearCannotSignOutAnActivePhone() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let phoneClient = client(id: "phone-client", updatedAt: 100)
    try keychain.set("phone-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector,
      clientService: MockClientService { throw CancellationError() }
    )
    clerk.client = phoneClient
    clerk.identityController.lastServerDate = Date(timeIntervalSince1970: 100)
    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenCleared(version: WatchSyncVersion(rawValue: 1)),
      clientUpdate: .notIncluded,
      environment: nil
    )

    WatchConnectivityCoordinator().apply(payload, from: .watch, to: clerk)
    await Task.yield()

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
    #expect(clerk.client?.id == phoneClient.id)
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 100))
  }

  @Test
  func stoppedCoordinatorDropsPayloadWaitingForLocalIdentityQueue() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      atomicIdentityStore: identityStore,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    let gate = AsyncGate()
    let blocker = clerk.identityController.enqueueLocalOperation { _ in
      await gate.wait()
    }
    let coordinator = WatchConnectivityCoordinator()
    coordinator.apply(
      WatchSyncPayload(
        deviceTokenUpdate: .tokenSet(
          token: "stale-token",
          version: WatchSyncVersion(rawValue: 1)
        ),
        clientUpdate: .snapshot(
          client: client(id: "stale-client", updatedAt: 100),
          serverFetchDate: Date(timeIntervalSince1970: 100),
          version: WatchSyncVersion(rawValue: 1)
        ),
        environment: nil
      ),
      from: .phone,
      to: clerk
    )

    coordinator.stopAcceptingIdentityUpdates()
    await gate.open()
    _ = try? await blocker.value
    await coordinator.waitForIdentityPublications()

    #expect(try identityStore.load() == nil)
    #expect(clerk.client == nil)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == nil)
  }

  @Test
  func invalidatedQueuedWatchOperationStillReleasesPublicationTracking() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      atomicIdentityStore: identityStore,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    let gate = AsyncGate()
    let blocker = clerk.identityController.enqueueLocalOperation { _ in
      await gate.wait()
    }
    let coordinator = WatchConnectivityCoordinator()
    coordinator.apply(
      WatchSyncPayload(
        deviceTokenUpdate: .tokenSet(
          token: "stale-token",
          version: WatchSyncVersion(rawValue: 1)
        ),
        clientUpdate: .snapshot(
          client: client(id: "stale-client", updatedAt: 100),
          serverFetchDate: Date(timeIntervalSince1970: 100),
          version: WatchSyncVersion(rawValue: 1)
        ),
        environment: nil
      ),
      from: .phone,
      to: clerk
    )
    #expect(coordinator.activeIdentityPublicationCount == 1)
    clerk.identityController.invalidatedThroughRevision = clerk.identityController.localOperationRevision

    await gate.open()
    _ = try? await blocker.value
    await coordinator.waitForIdentityPublications()

    #expect(coordinator.activeIdentityPublicationCount == 0)
    #expect(try identityStore.load() == nil)
    #expect(clerk.client == nil)
  }

  @Test
  func awaitedClearPersistsWatchTombstoneAndRejectsStalePeerIdentity() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let legacyShared = InMemoryKeychain()
    let appLocal = InMemoryKeychain()
    let identityKeychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: identityKeychain)
    let initialIdentity = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "current-token",
      client: client(id: "current-client", updatedAt: 100),
      serverDate: Date(timeIntervalSince1970: 100)
    )
    try identityStore.save(initialIdentity)
    try WatchSyncMetadataStore(keychain: legacyShared).save(
      WatchSyncMetadataRecord(
        deviceTokenState: .set,
        deviceTokenVersion: 9,
        authState: .set,
        authVersion: 9
      )
    )
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: legacyShared,
      appLocalKeychain: appLocal,
      identityKeychain: identityKeychain,
      atomicIdentityStore: identityStore,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    clerk.hydrateIdentityIfNeeded(initialIdentity)

    try await clerk.clearAllKeychainItemsAndWait()

    let metadata = try WatchSyncMetadataStore(keychain: appLocal).load()
    let clearVersion = try #require(metadata.authVersion)
    #expect(clearVersion > 9)
    #expect(metadata.deviceTokenVersion == clearVersion)
    #expect(metadata.deviceTokenState == .cleared)
    #expect(metadata.authState == .cleared)
    #expect(!metadata.hasPendingIdentityMetadata)

    let stalePayload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "stale-token",
        version: WatchSyncVersion(rawValue: 9)
      ),
      clientUpdate: .snapshot(
        client: client(id: "stale-client", updatedAt: 90),
        serverFetchDate: Date(timeIntervalSince1970: 90),
        version: WatchSyncVersion(rawValue: 9)
      ),
      environment: nil
    )
    let coordinator = WatchConnectivityCoordinator()
    coordinator.apply(stalePayload, from: .watch, to: clerk)
    await coordinator.waitForIdentityPublications()

    #expect(clerk.identityController.localDeviceToken == nil)
    #expect(clerk.client == nil)
    #expect(try identityStore.load() == nil)
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
  }

  @Test
  func rejectedWatchDeviceTokenSetPreservesPhoneDeviceToken() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let phoneServerDate = Date(timeIntervalSince1970: 200)
    let originalGeneration = clerk.clientResponseGeneration
    let phoneClient = client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 4000, lastActiveSessionId: "session-phone")
    let watchClient = client(id: "client-watch", signInId: "sign-in-watch", updatedAt: 3000, lastActiveSessionId: "session-watch")
    try keychain.set("phone-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
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
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
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
    clerk.identityController.lastServerDate = phoneServerDate

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
    let metadata = try WatchSyncMetadataStore(keychain: keychain).load()
    #expect(metadata.deviceTokenState == .set)
    #expect(metadata.deviceTokenVersion == 1)
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
    clerk.identityController.lastServerDate = phoneServerDate

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
  }

  @Test
  func watchPayloadSeedsPhoneWhenNoLocalClient() {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    clerk.client = nil
    let watchServerDate = Date(timeIntervalSince1970: 100)

    let payload = WatchSyncPayload(
      deviceToken: "watch-token",
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
  func clientSnapshotWithoutPairedTokenDoesNotReuseLocalToken() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("phone-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    clerk.applyResponseClient(
      client(id: "client-local", signInId: "sign-in-local", updatedAt: 4000, lastActiveSessionId: "session-local"),
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 100)
    )

    let localClient = try #require(clerk.client)
    let payload = WatchSyncPayload(
      deviceTokenUpdate: .notIncluded,
      clientUpdate: .snapshot(
        client: client(id: "client-phone", signInId: "sign-in-phone", updatedAt: 3000, lastActiveSessionId: "session-phone"),
        serverFetchDate: Date(timeIntervalSince1970: 200),
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )

    apply(payload, from: .phone, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == localClient.id)
    #expect(clerk.client?.signIn?.id == localClient.signIn?.id)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
  }

  @Test
  func changedTokenWithoutClientClearsOldClientBeforeRefresh() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("old-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    clerk.client = client(id: "old-client", updatedAt: 100)
    clerk.identityController.lastServerDate = Date(timeIntervalSince1970: 50)
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector,
      clientService: MockClientService(get: { throw CancellationError() })
    )
    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "new-token",
        version: WatchSyncVersion(rawValue: 1)
      ),
      clientUpdate: .notIncluded,
      environment: nil
    )

    WatchConnectivityCoordinator().apply(payload, from: .phone, to: clerk)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "new-token")
    #expect(clerk.client == nil)
    #expect(clerk.lastClientServerFetchDate == nil)
  }

  @Test
  func adoptedIdentityWatchUpdateRefreshesHydratedToken() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let previous = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "old-token",
      client: client(id: "old-client", updatedAt: 100),
      serverDate: Date(timeIntervalSince1970: 50)
    )
    try identityStore.save(previous)
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      atomicIdentityStore: identityStore,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    clerk.hydrateIdentityIfNeeded(previous)
    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "new-token",
        version: WatchSyncVersion(rawValue: 1)
      ),
      clientUpdate: .snapshot(
        client: client(id: "new-client", updatedAt: 200),
        serverFetchDate: Date(timeIntervalSince1970: 100),
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )

    let coordinator = WatchConnectivityCoordinator()
    coordinator.apply(payload, from: .phone, to: clerk)
    await coordinator.waitForIdentityPublications()

    #expect(clerk.identityController.localDeviceToken == "new-token")
    #expect(try identityStore.load()?.deviceToken == "new-token")
    #expect(clerk.client?.id == "new-client")
  }

  @Test
  func rejectedTokenUpdateSuppressesPairedClient() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("current-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    let currentClient = client(id: "current-client", updatedAt: 100)
    clerk.client = currentClient
    try WatchSyncMetadataStore(keychain: keychain).save(
      WatchSyncMetadataRecord(
        deviceTokenState: .set,
        deviceTokenVersion: 3,
        authState: .set,
        authVersion: 1
      )
    )
    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "rejected-token",
        version: WatchSyncVersion(rawValue: 2)
      ),
      clientUpdate: .snapshot(
        client: client(id: "rejected-client", updatedAt: 200),
        serverFetchDate: Date(timeIntervalSince1970: 200),
        version: WatchSyncVersion(rawValue: 2)
      ),
      environment: nil
    )

    apply(payload, from: .phone, to: clerk, keychain: keychain)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "current-token")
    #expect(clerk.client?.id == currentClient.id)
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
    let metadata = try WatchSyncMetadataStore(keychain: keychain).load()
    #expect(metadata.deviceTokenState == .cleared)
    #expect(metadata.deviceTokenVersion == 3)
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
    let metadata = try WatchSyncMetadataStore(keychain: keychain).load()
    #expect(metadata.deviceTokenState == .cleared)
    #expect(metadata.deviceTokenVersion == 3)
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
    let metadata = try WatchSyncMetadataStore(keychain: keychain).load()
    #expect(metadata.deviceTokenState == .cleared)
    #expect(metadata.deviceTokenVersion == 3)
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

  @Test
  func legacyVersionlessDeviceTokenStatePayloadIsAccepted() throws {
    let tokenSetPayload = try #require(WatchSyncPayload(applicationContext: [
      "watchSyncDeviceTokenState": "set",
      "clerkDeviceToken": "legacy-token",
    ]))
    #expect(tokenSetPayload.deviceTokenUpdate == .tokenSet(token: "legacy-token", version: nil))

    let tokenClearedPayload = try #require(WatchSyncPayload(applicationContext: [
      "watchSyncDeviceTokenState": "cleared",
    ]))
    #expect(tokenClearedPayload.deviceTokenUpdate == .tokenCleared(version: nil))
  }

  @Test
  func legacyVersionlessAuthStatePayloadIsAccepted() throws {
    let serverFetchDate = Date(timeIntervalSince1970: 300)
    let payloadClient = client(id: "client-legacy", updatedAt: 4000)
    let snapshotPayload = try #require(try WatchSyncPayload(applicationContext: [
      "watchSyncAuthState": "set",
      "clerkClient": JSONEncoder.clerkEncoder.encode(payloadClient),
      "clerkClientServerFetchDate": serverFetchDate.timeIntervalSince1970,
    ]))
    #expect(snapshotPayload.client?.id == payloadClient.id)
    #expect(snapshotPayload.clientUpdate.version == nil)
    #expect(snapshotPayload.clientServerFetchDate == serverFetchDate)

    let clearedPayload = try #require(WatchSyncPayload(applicationContext: [
      "watchSyncAuthState": "cleared",
      "clerkClientServerFetchDate": serverFetchDate.timeIntervalSince1970,
    ]))
    #expect(clearedPayload.client == nil)
    #expect(clearedPayload.clientUpdate.version == nil)
    #expect(clearedPayload.clientServerFetchDate == serverFetchDate)
  }

  @Test
  func partialUnknownOrInvalidMetadataIsRejected() {
    let invalidContexts: [[String: Any]] = [
      ["watchSyncAuthState": "set"],
      ["watchSyncAuthVersion": 1],
      ["watchSyncAuthState": "unknown", "watchSyncAuthVersion": 1],
      ["watchSyncDeviceTokenState": "set", "watchSyncDeviceTokenVersion": -1],
      ["watchSyncDeviceTokenState": "set", "watchSyncDeviceTokenVersion": 1.5],
      ["watchSyncDeviceTokenState": "cleared", "watchSyncDeviceTokenVersion": Double(Int.max)],
      [
        "watchSyncAuthState": "cleared",
        "watchSyncAuthVersion": 1,
        "clerkClientServerFetchDate": Double.infinity,
      ],
    ]
    for context in invalidContexts {
      #expect(WatchSyncPayload(applicationContext: context) == nil)
    }
  }

  @Test
  func tokenWriteFailureSuppressesPairedClient() {
    configureClerkForTesting()
    let clerk = Clerk()
    let previousClient = client(id: "previous", updatedAt: 100)
    clerk.client = previousClient
    clerk.identityController.lastServerDate = Date(timeIntervalSince1970: 50)
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: InMemoryKeychain(),
      identityKeychain: SetFailingKeychain(),
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(token: "new-token", version: WatchSyncVersion(rawValue: 1)),
      clientUpdate: .snapshot(
        client: client(id: "new-client", updatedAt: 200),
        serverFetchDate: nil,
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )

    WatchConnectivityCoordinator().apply(payload, from: .phone, to: clerk)

    #expect(clerk.client?.id == previousClient.id)
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 50))
  }

  @Test
  func metadataReadFailureRejectsPairedIdentityUpdate() {
    configureClerkForTesting()
    let clerk = Clerk()
    let previousClient = client(id: "previous", updatedAt: 100)
    clerk.client = previousClient
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: ReadFailingKeychain(),
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(token: "new-token", version: WatchSyncVersion(rawValue: 1)),
      clientUpdate: .snapshot(
        client: client(id: "new-client", updatedAt: 200),
        serverFetchDate: Date(timeIntervalSince1970: 200),
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )

    WatchConnectivityCoordinator().apply(payload, from: .phone, to: clerk)

    #expect(clerk.client?.id == previousClient.id)
  }

  @Test
  func failedAuthMetadataSaveDoesNotAdvanceAcceptedGeneration() throws {
    let keychain = PromotionFailingKeychain()
    let store = WatchSyncMetadataStore(keychain: keychain)
    let coordinator = WatchConnectivityCoordinator()
    let previousClient = client(id: "previous", updatedAt: 100)
    let nextClient = client(id: "next", updatedAt: 200)
    var record = WatchSyncMetadataRecord.empty
    record.authState = .set
    record.authVersion = 1
    record.authFingerprint = try WatchConnectivityCoordinator.authFingerprint(
      client: previousClient,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    try store.save(record)

    #expect(throws: PromotionFailingKeychain.Failure.self) {
      _ = try coordinator.persistAuthState(
        .set,
        version: WatchSyncVersion(rawValue: 2),
        client: nextClient,
        serverDate: Date(timeIntervalSince1970: 200),
        keychain: keychain
      )
    }

    #expect(try coordinator.currentAuthVersion(keychain: keychain) == WatchSyncVersion(rawValue: 1))
    #expect(try store.load().authVersion == 1)

    keychain.failWrites = false
    _ = try coordinator.persistAuthState(
      .set,
      version: WatchSyncVersion(rawValue: 2),
      client: nextClient,
      serverDate: Date(timeIntervalSince1970: 200),
      keychain: keychain
    )

    #expect(try coordinator.currentAuthVersion(keychain: keychain) == WatchSyncVersion(rawValue: 2))
    #expect(try store.load().authVersion == 2)
  }

  @Test
  func failedSharedIdentityMetadataSaveDoesNotAdvanceAcceptedGeneration() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let metadataKeychain = PromotionFailingKeychain()
    let fallbackKeychain = InMemoryKeychain()
    let store = WatchSyncMetadataStore(keychain: metadataKeychain)
    let coordinator = WatchConnectivityCoordinator()
    let previousClient = client(id: "previous", updatedAt: 100)
    let nextClient = client(id: "next", updatedAt: 200)
    var record = WatchSyncMetadataRecord.empty
    record.authState = .set
    record.authVersion = 1
    record.authFingerprint = try WatchConnectivityCoordinator.authFingerprint(
      client: previousClient,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    try store.save(record)
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: fallbackKeychain,
      appLocalKeychain: metadataKeychain,
      identityKeychain: fallbackKeychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    clerk.client = nextClient
    clerk.identityController.lastServerDate = Date(timeIntervalSince1970: 200)

    #expect(throws: PromotionFailingKeychain.Failure.self) {
      try coordinator.handle(.identityDidChange, from: clerk)
    }

    #expect(
      try coordinator.currentAuthVersion(keychain: clerk.dependencies.watchSyncKeychain)
        == WatchSyncVersion(rawValue: 1)
    )
    #expect(try store.load().authVersion == 1)

    metadataKeychain.failWrites = false
    try coordinator.handle(.identityDidChange, from: clerk)

    #expect(
      try coordinator.currentAuthVersion(keychain: clerk.dependencies.watchSyncKeychain)
        == WatchSyncVersion(rawValue: 2)
    )
    #expect(try store.load().authVersion == 2)
  }

  @Test
  func clearTombstoneWriteFailurePreservesExistingWatermark() throws {
    let keychain = UpdateFailingKeychain()
    let store = WatchSyncMetadataStore(keychain: keychain)
    let client = client(id: "stale", updatedAt: 100)
    let existing = try WatchSyncMetadataRecord(
      deviceTokenState: .set,
      deviceTokenVersion: 4,
      deviceTokenFingerprint: WatchConnectivityCoordinator.deviceTokenFingerprint("stale-token"),
      authState: .set,
      authVersion: 4,
      authFingerprint: WatchConnectivityCoordinator.authFingerprint(
        client: client,
        serverDate: Date(timeIntervalSince1970: 100)
      )
    )
    try store.save(existing)
    keychain.failNextExistingItemWrite()

    #expect(throws: UpdateFailingKeychain.Failure.update) {
      try store.saveClearTombstone(minimumVersion: 10)
    }

    #expect(try store.load() == existing)
  }

  @Test
  func clearTombstoneReplacesCorruptMetadata() throws {
    let keychain = InMemoryKeychain()
    let store = WatchSyncMetadataStore(keychain: keychain)
    try keychain.set(
      Data("not-json".utf8),
      forKey: ClerkKeychainKey.watchSyncMetadata.rawValue
    )

    let tombstone = try store.saveClearTombstone(minimumVersion: 10)

    #expect(tombstone.deviceTokenState == .cleared)
    #expect(tombstone.deviceTokenVersion == 10)
    #expect(tombstone.authState == .cleared)
    #expect(tombstone.authVersion == 10)
    #expect(try store.load() == tombstone)
  }

  @Test
  func clearTombstoneReplacesMalformedLegacyStringMetadata() throws {
    let keychain = InMemoryKeychain()
    let store = WatchSyncMetadataStore(keychain: keychain)
    try keychain.set(
      Data([0xFF]),
      forKey: ClerkKeychainKey.watchSyncAuthState.rawValue
    )

    let tombstone = try store.saveClearTombstone(minimumVersion: 10)

    #expect(tombstone.deviceTokenState == .cleared)
    #expect(tombstone.deviceTokenVersion == 10)
    #expect(tombstone.authState == .cleared)
    #expect(tombstone.authVersion == 10)
    #expect(try store.load() == tombstone)
  }

  @Test
  func clearTombstoneClearsInheritedSources() throws {
    let keychain = InMemoryKeychain()
    let store = WatchSyncMetadataStore(keychain: keychain)
    var record = WatchSyncMetadataRecord.empty
    record.deviceTokenState = .set
    record.deviceTokenVersion = 4
    record.deviceTokenSource = .phone
    record.authState = .set
    record.authVersion = 4
    record.authSource = .watch
    try store.save(record)

    let tombstone = try store.saveClearTombstone(minimumVersion: 10)

    #expect(tombstone.deviceTokenState == .cleared)
    #expect(tombstone.deviceTokenVersion == 10)
    #expect(tombstone.deviceTokenSource == nil)
    #expect(tombstone.authState == .cleared)
    #expect(tombstone.authVersion == 10)
    #expect(tombstone.authSource == nil)
    #expect(try store.load() == tombstone)
  }

  @Test
  func legacyDeviceTokenStateWithoutVersionMigratesAsVersionZero() throws {
    let keychain = InMemoryKeychain()
    let store = WatchSyncMetadataStore(keychain: keychain)
    try keychain.set("set", forKey: ClerkKeychainKey.watchSyncDeviceTokenState.rawValue)

    let record = try store.load()

    #expect(record.deviceTokenState == .set)
    #expect(record.deviceTokenVersion == 0)
    #expect(record.authState == nil)
    #expect(record.authVersion == nil)
    #expect(try keychain.data(forKey: ClerkKeychainKey.watchSyncMetadata.rawValue) != nil)
  }

  @Test
  func legacyAuthStateWithoutVersionMigratesAsVersionZero() throws {
    let keychain = InMemoryKeychain()
    let store = WatchSyncMetadataStore(keychain: keychain)
    try keychain.set("cleared", forKey: ClerkKeychainKey.watchSyncAuthState.rawValue)

    let record = try store.load()

    #expect(record.deviceTokenState == nil)
    #expect(record.deviceTokenVersion == nil)
    #expect(record.authState == .cleared)
    #expect(record.authVersion == 0)
    #expect(try keychain.data(forKey: ClerkKeychainKey.watchSyncMetadata.rawValue) != nil)
  }

  @Test
  func legacyVersionWithoutStateIsCorrupt() throws {
    let keychain = InMemoryKeychain()
    let store = WatchSyncMetadataStore(keychain: keychain)
    try keychain.set("1", forKey: ClerkKeychainKey.watchSyncAuthVersion.rawValue)

    #expect(throws: WatchSyncMetadataStoreError.corrupt) {
      try store.load()
    }
  }

  @Test
  func clearTombstonePropagatesMetadataReadFailure() {
    let store = WatchSyncMetadataStore(keychain: ReadFailingKeychain())

    #expect(throws: ReadFailingKeychain.Failure.read) {
      try store.saveClearTombstone(minimumVersion: 10)
    }
  }

  @Test
  func pendingMetadataWatermarkRejectsRollbackAfterFinalWriteFailure() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let metadataKeychain = PromotionFailingKeychain()
    let identityKeychain = InMemoryKeychain()
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: metadataKeychain,
      appLocalKeychain: metadataKeychain,
      identityKeychain: identityKeychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    let accepted = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "version-3-token",
        version: WatchSyncVersion(rawValue: 3)
      ),
      clientUpdate: .snapshot(
        client: client(id: "version-3-client", updatedAt: 300),
        serverFetchDate: Date(timeIntervalSince1970: 300),
        version: WatchSyncVersion(rawValue: 3)
      ),
      environment: nil
    )

    WatchConnectivityCoordinator().apply(accepted, from: .phone, to: clerk)

    var metadata = try WatchSyncMetadataStore(keychain: metadataKeychain).load()
    #expect(clerk.client?.id == "version-3-client")
    #expect(metadata.authVersion == nil)
    #expect(metadata.pendingAuthVersion == 3)
    #expect(metadata.pendingDeviceTokenVersion == 3)

    let stale = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "version-2-token",
        version: WatchSyncVersion(rawValue: 2)
      ),
      clientUpdate: .snapshot(
        client: client(id: "version-2-client", updatedAt: 200),
        serverFetchDate: Date(timeIntervalSince1970: 200),
        version: WatchSyncVersion(rawValue: 2)
      ),
      environment: nil
    )
    WatchConnectivityCoordinator().apply(stale, from: .phone, to: clerk)

    #expect(clerk.client?.id == "version-3-client")
    #expect(try identityKeychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "version-3-token")

    let conflictingSameVersion = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "conflicting-token",
        version: WatchSyncVersion(rawValue: 3)
      ),
      clientUpdate: .snapshot(
        client: client(id: "conflicting-client", updatedAt: 301),
        serverFetchDate: Date(timeIntervalSince1970: 301),
        version: WatchSyncVersion(rawValue: 3)
      ),
      environment: nil
    )
    WatchConnectivityCoordinator().apply(conflictingSameVersion, from: .phone, to: clerk)

    #expect(clerk.client?.id == "version-3-client")
    #expect(try identityKeychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "version-3-token")

    metadataKeychain.failWrites = false
    WatchConnectivityCoordinator().apply(accepted, from: .phone, to: clerk)

    metadata = try WatchSyncMetadataStore(keychain: metadataKeychain).load()
    #expect(metadata.authVersion == 3)
    #expect(metadata.deviceTokenVersion == 3)
    #expect(!metadata.hasPendingIdentityMetadata)
  }

  @Test
  func nonAuthoritativeExactRetryCanCompletePendingIdentityAfterSaveFailure() async throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let metadataKeychain = InMemoryKeychain()
    let initialIdentity = SharedSessionLocalIdentity(
      state: .cleared,
      deviceToken: nil,
      client: nil,
      serverDate: nil
    )
    let identityStore = FailingOnceIdentityStore(identity: initialIdentity)
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: metadataKeychain,
      atomicIdentityStore: identityStore,
      telemetryCollector: clerk.dependencies.telemetryCollector,
      clientService: MockClientService(get: { throw CancellationError() })
    )
    clerk.hydrateIdentityIfNeeded(initialIdentity)
    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "watch-token",
        version: WatchSyncVersion(rawValue: 1)
      ),
      clientUpdate: .snapshot(
        client: client(id: "watch-client", updatedAt: 100),
        serverFetchDate: Date(timeIntervalSince1970: 100),
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )
    let coordinator = WatchConnectivityCoordinator()

    coordinator.apply(payload, from: .watch, to: clerk)
    await coordinator.waitForIdentityPublications()

    var metadata = try WatchSyncMetadataStore(keychain: metadataKeychain).load()
    #expect(clerk.client == nil)
    #expect(!metadata.hasPendingIdentityMetadata)
    _ = try WatchSyncPayload(
      clerk: clerk,
      metadata: metadata,
      authGeneration: .initial
    )

    coordinator.apply(payload, from: .watch, to: clerk)
    await coordinator.waitForIdentityPublications()

    metadata = try WatchSyncMetadataStore(keychain: metadataKeychain).load()
    #expect(clerk.identityController.localDeviceToken == "watch-token")
    #expect(clerk.client?.id == "watch-client")
    #expect(try identityStore.load()?.client?.id == "watch-client")
    #expect(metadata.deviceTokenVersion == 1)
    #expect(metadata.authVersion == 1)
    #expect(!metadata.hasPendingIdentityMetadata)
  }

  @Test
  func versionlessAuthoritativeAuthPayloadCannotOverrideAcceptedVersionZero() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let currentClient = client(id: "accepted-zero-client", updatedAt: 400)
    let currentDate = Date(timeIntervalSince1970: 400)
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    clerk.client = currentClient
    clerk.identityController.lastServerDate = currentDate
    var record = WatchSyncMetadataRecord.empty
    record.authState = .set
    record.authVersion = 0
    record.authFingerprint = try WatchConnectivityCoordinator.authFingerprint(
      client: currentClient,
      serverDate: currentDate
    )
    try WatchSyncMetadataStore(keychain: keychain).save(record)
    let payload = WatchSyncPayload(
      deviceTokenUpdate: .notIncluded,
      clientUpdate: .cleared(
        serverFetchDate: Date(timeIntervalSince1970: 500),
        version: nil
      ),
      environment: nil
    )

    WatchConnectivityCoordinator().apply(payload, from: .phone, to: clerk)

    #expect(clerk.client?.id == currentClient.id)
    #expect(try WatchSyncMetadataStore(keychain: keychain).load().authVersion == 0)
  }

  @Test
  func acceptedAuthoritativeVersionIsIdempotentButRejectsDifferentPayload() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    let accepted = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "accepted-token",
        version: WatchSyncVersion(rawValue: 4)
      ),
      clientUpdate: .snapshot(
        client: client(id: "accepted-client", updatedAt: 400),
        serverFetchDate: Date(timeIntervalSince1970: 400),
        version: WatchSyncVersion(rawValue: 4)
      ),
      environment: nil
    )
    let coordinator = WatchConnectivityCoordinator()

    coordinator.apply(accepted, from: .phone, to: clerk)
    coordinator.apply(accepted, from: .phone, to: clerk)

    var metadata = try WatchSyncMetadataStore(keychain: keychain).load()
    #expect(metadata.deviceTokenFingerprint != nil)
    #expect(metadata.authFingerprint != nil)

    let conflicting = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "conflicting-token",
        version: WatchSyncVersion(rawValue: 4)
      ),
      clientUpdate: .snapshot(
        client: client(id: "conflicting-client", updatedAt: 401),
        serverFetchDate: Date(timeIntervalSince1970: 401),
        version: WatchSyncVersion(rawValue: 4)
      ),
      environment: nil
    )
    coordinator.apply(conflicting, from: .phone, to: clerk)

    metadata = try WatchSyncMetadataStore(keychain: keychain).load()
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "accepted-token")
    #expect(clerk.client?.id == "accepted-client")
    #expect(metadata.deviceTokenVersion == 4)
    #expect(metadata.authVersion == 4)
  }

  @Test
  func authoritativePhonePayloadResetsStaleUnknownWatchWatermark() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let staleDate = Date(timeIntervalSince1970: 900)
    let staleClient = client(id: "stale-watch-client", updatedAt: 900)
    try WatchSyncMetadataStore(keychain: keychain).save(WatchSyncMetadataRecord(
      deviceTokenState: .set,
      deviceTokenVersion: 111,
      deviceTokenFingerprint: WatchConnectivityCoordinator.deviceTokenFingerprint("stale-watch-token"),
      authState: .set,
      authVersion: 144,
      authFingerprint: WatchConnectivityCoordinator.authFingerprint(
        client: staleClient,
        serverDate: staleDate
      )
    ))
    let phonePayload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "phone-token",
        version: WatchSyncVersion(rawValue: 14)
      ),
      clientUpdate: .snapshot(
        client: client(id: "phone-client", updatedAt: 1000),
        serverFetchDate: Date(timeIntervalSince1970: 1000),
        version: WatchSyncVersion(rawValue: 14)
      ),
      environment: nil
    )

    apply(phonePayload, from: .phone, to: clerk, keychain: keychain)

    let metadata = try WatchSyncMetadataStore(keychain: keychain).load()
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
    #expect(clerk.client?.id == "phone-client")
    #expect(metadata.deviceTokenVersion == 14)
    #expect(metadata.deviceTokenSource == .phone)
    #expect(metadata.authVersion == 14)
    #expect(metadata.authSource == .phone)
    #expect(!metadata.hasPendingIdentityMetadata)
  }

  @Test
  func authoritativePhonePayloadCanResetOnlyStaleTokenWatermark() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let currentDate = Date(timeIntervalSince1970: 900)
    let currentClient = client(id: "current-client", updatedAt: 900)
    clerk.applyResponseClient(
      currentClient,
      responseSequence: 1,
      serverDate: currentDate
    )
    try WatchSyncMetadataStore(keychain: keychain).save(WatchSyncMetadataRecord(
      deviceTokenState: .set,
      deviceTokenVersion: 100,
      deviceTokenFingerprint: WatchConnectivityCoordinator.deviceTokenFingerprint("stale-watch-token"),
      authState: .set,
      authVersion: 1,
      authFingerprint: WatchConnectivityCoordinator.authFingerprint(
        client: currentClient,
        serverDate: currentDate
      )
    ))
    let phonePayload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "phone-token",
        version: WatchSyncVersion(rawValue: 2)
      ),
      clientUpdate: .snapshot(
        client: client(id: "phone-client", updatedAt: 1000),
        serverFetchDate: Date(timeIntervalSince1970: 1000),
        version: WatchSyncVersion(rawValue: 2)
      ),
      environment: nil
    )

    apply(phonePayload, from: .phone, to: clerk, keychain: keychain)

    let metadata = try WatchSyncMetadataStore(keychain: keychain).load()
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "phone-token")
    #expect(clerk.client?.id == "phone-client")
    #expect(metadata.deviceTokenVersion == 2)
    #expect(metadata.deviceTokenSource == .phone)
    #expect(metadata.authVersion == 2)
    #expect(metadata.authSource == .phone)
    #expect(!metadata.hasPendingIdentityMetadata)
  }

  @Test
  func lowerAuthoritativePhonePayloadCannotRollbackAcceptedPhoneWatermark() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let accepted = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "accepted-token",
        version: WatchSyncVersion(rawValue: 4)
      ),
      clientUpdate: .snapshot(
        client: client(id: "accepted-client", updatedAt: 400),
        serverFetchDate: Date(timeIntervalSince1970: 400),
        version: WatchSyncVersion(rawValue: 4)
      ),
      environment: nil
    )
    apply(accepted, from: .phone, to: clerk, keychain: keychain)
    let stale = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "stale-token",
        version: WatchSyncVersion(rawValue: 3)
      ),
      clientUpdate: .snapshot(
        client: client(id: "stale-client", updatedAt: 300),
        serverFetchDate: Date(timeIntervalSince1970: 300),
        version: WatchSyncVersion(rawValue: 3)
      ),
      environment: nil
    )

    apply(stale, from: .phone, to: clerk, keychain: keychain)

    let metadata = try WatchSyncMetadataStore(keychain: keychain).load()
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "accepted-token")
    #expect(clerk.client?.id == "accepted-client")
    #expect(metadata.deviceTokenVersion == 4)
    #expect(metadata.deviceTokenSource == .phone)
    #expect(metadata.authVersion == 4)
    #expect(metadata.authSource == .phone)
  }

  @Test
  func lowerAuthoritativePhonePayloadCannotResetClearTombstone() throws {
    let tombstoneSources: [WatchSyncSource?] = [nil, .watch]

    for tombstoneSource in tombstoneSources {
      configureClerkForTesting()
      let clerk = Clerk()
      let keychain = InMemoryKeychain()
      var record = WatchSyncMetadataRecord.empty
      record.deviceTokenState = .cleared
      record.deviceTokenVersion = 100
      record.deviceTokenFingerprint = WatchConnectivityCoordinator.deviceTokenFingerprint(nil)
      record.deviceTokenSource = tombstoneSource
      record.authState = .cleared
      record.authVersion = 100
      record.authFingerprint = try WatchConnectivityCoordinator.authFingerprint(
        client: nil,
        serverDate: nil
      )
      record.authSource = tombstoneSource
      try WatchSyncMetadataStore(keychain: keychain).save(record)
      let stalePhonePayload = WatchSyncPayload(
        deviceTokenUpdate: .tokenSet(
          token: "stale-phone-token",
          version: WatchSyncVersion(rawValue: 14)
        ),
        clientUpdate: .snapshot(
          client: client(id: "stale-phone-client", updatedAt: 1000),
          serverFetchDate: Date(timeIntervalSince1970: 1000),
          version: WatchSyncVersion(rawValue: 14)
        ),
        environment: nil
      )

      apply(stalePhonePayload, from: .phone, to: clerk, keychain: keychain)

      let metadata = try WatchSyncMetadataStore(keychain: keychain).load()
      #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == nil)
      #expect(clerk.client == nil)
      #expect(metadata.deviceTokenState == .cleared)
      #expect(metadata.deviceTokenVersion == 100)
      #expect(metadata.deviceTokenSource == tombstoneSource)
      #expect(metadata.authState == .cleared)
      #expect(metadata.authVersion == 100)
      #expect(metadata.authSource == tombstoneSource)
    }
  }

  @Test
  func acceptedMetadataCannotReplayAfterDurableIdentityWasCleared() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    let staleClient = client(id: "stale-client", updatedAt: 400)
    let staleDate = Date(timeIntervalSince1970: 400)
    try WatchSyncMetadataStore(keychain: keychain).save(WatchSyncMetadataRecord(
      deviceTokenState: .set,
      deviceTokenVersion: 4,
      deviceTokenFingerprint: WatchConnectivityCoordinator.deviceTokenFingerprint("stale-token"),
      authState: .set,
      authVersion: 4,
      authFingerprint: WatchConnectivityCoordinator.authFingerprint(
        client: staleClient,
        serverDate: staleDate
      )
    ))
    let stalePayload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "stale-token",
        version: WatchSyncVersion(rawValue: 4)
      ),
      clientUpdate: .snapshot(
        client: staleClient,
        serverFetchDate: staleDate,
        version: WatchSyncVersion(rawValue: 4)
      ),
      environment: nil
    )

    WatchConnectivityCoordinator().apply(stalePayload, from: .phone, to: clerk)

    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == nil)
    #expect(clerk.client == nil)
  }

  @Test
  func localStorageClearPersistsWatchClearMetadata() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    let staleClient = client(id: "stale-client", updatedAt: 400)
    try WatchSyncMetadataStore(keychain: keychain).save(WatchSyncMetadataRecord(
      deviceTokenState: .set,
      deviceTokenVersion: 4,
      deviceTokenFingerprint: WatchConnectivityCoordinator.deviceTokenFingerprint("stale-token"),
      authState: .set,
      authVersion: 4,
      authFingerprint: WatchConnectivityCoordinator.authFingerprint(
        client: staleClient,
        serverDate: Date(timeIntervalSince1970: 400)
      )
    ))
    let coordinator = WatchConnectivityCoordinator()

    try coordinator.handle(.localStorageDidClear, from: clerk)

    let metadata = try WatchSyncMetadataStore(keychain: keychain).load()
    let tokenVersion = try #require(metadata.deviceTokenVersion)
    let authVersion = try #require(metadata.authVersion)
    #expect(metadata.deviceTokenState == .cleared)
    #expect(metadata.authState == .cleared)
    #expect(tokenVersion > 4)
    #expect(authVersion == tokenVersion)
    #expect(!metadata.hasPendingIdentityMetadata)

    let payload = try WatchSyncPayload(
      clerk: clerk,
      metadata: metadata,
      authGeneration: WatchSyncVersion(rawValue: authVersion)
    )
    #expect(payload.deviceTokenUpdate == .tokenCleared(version: WatchSyncVersion(rawValue: tokenVersion)))
    #expect(payload.clientUpdate == .cleared(serverFetchDate: nil, version: WatchSyncVersion(rawValue: authVersion)))
  }

  @Test
  func canceledRefreshCompletionCannotClearReplacementRefreshState() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let coordinator = WatchConnectivityCoordinator()
    let canceledTaskID = UUID()
    let replacementTaskID = UUID()

    #expect(coordinator.markRefreshScheduled(canceledTaskID))
    try coordinator.handle(.localStorageDidClear, from: clerk)
    #expect(coordinator.markRefreshScheduled(replacementTaskID))

    coordinator.clearRefreshScheduled(canceledTaskID)

    #expect(!coordinator.markRefreshScheduled(UUID()))
    coordinator.clearRefreshScheduled(replacementTaskID)
  }

  @Test
  func corruptedMetadataRejectsPairedIdentityUpdate() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set(Data("not-json".utf8), forKey: ClerkKeychainKey.watchSyncMetadata.rawValue)
    let previousClient = client(id: "previous", updatedAt: 100)
    clerk.client = previousClient
    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(token: "new-token", version: WatchSyncVersion(rawValue: 1)),
      clientUpdate: .snapshot(
        client: client(id: "new-client", updatedAt: 200),
        serverFetchDate: Date(timeIntervalSince1970: 200),
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )

    apply(payload, from: .phone, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == previousClient.id)
  }

  @Test
  func acceptedPayloadWithoutServerDatePreservesPreviousDate() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("old-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    clerk.identityController.lastServerDate = Date(timeIntervalSince1970: 100)
    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(token: "new-token", version: WatchSyncVersion(rawValue: 1)),
      clientUpdate: .snapshot(
        client: client(id: "new-client", updatedAt: 200),
        serverFetchDate: nil,
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )

    apply(payload, from: .phone, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == "new-client")
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 100))
  }

  @Test
  func tokenClearPairedWithActiveClientIsRejectedAsOneTransition() throws {
    configureClerkForTesting()
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    try keychain.set("old-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    let previousClient = client(id: "previous", updatedAt: 100)
    clerk.client = previousClient
    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenCleared(version: WatchSyncVersion(rawValue: 1)),
      clientUpdate: .snapshot(
        client: client(id: "invalid", updatedAt: 200),
        serverFetchDate: nil,
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )

    apply(payload, from: .phone, to: clerk, keychain: keychain)

    #expect(clerk.client?.id == previousClient.id)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "old-token")
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

private final class MetadataReadCountingKeychain: @unchecked Sendable, KeychainStorage {
  private let lock = NSLock()
  private let backing = InMemoryKeychain()
  private var metadataReads = 0

  var metadataReadCount: Int {
    lock.withLock { metadataReads }
  }

  func resetMetadataReadCount() {
    lock.withLock { metadataReads = 0 }
  }

  func set(_ data: Data, forKey key: String) throws {
    try backing.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    if key == ClerkKeychainKey.watchSyncMetadata.rawValue {
      lock.withLock { metadataReads += 1 }
    }
    return try backing.data(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    try backing.deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try backing.hasItem(forKey: key)
  }
}

private actor AsyncGate {
  private var isOpen = false
  private var continuation: CheckedContinuation<Void, Never>?

  func wait() async {
    guard !isOpen else { return }
    await withCheckedContinuation { continuation = $0 }
  }

  func open() {
    isOpen = true
    continuation?.resume()
    continuation = nil
  }
}

private final class ReadFailingKeychain: @unchecked Sendable, KeychainStorage {
  enum Failure: Error {
    case read
  }

  func set(_: Data, forKey _: String) throws {}

  func data(forKey _: String) throws -> Data? {
    throw Failure.read
  }

  func deleteItem(forKey _: String) throws {}

  func hasItem(forKey _: String) throws -> Bool {
    throw Failure.read
  }
}

private final class FailingOnceIdentityStore: @unchecked Sendable, SharedSessionLocalIdentityStoring {
  enum Failure: Error {
    case save
  }

  private let lock = NSLock()
  private var record: SharedSessionLocalIdentityRecord?
  private var shouldFailNextSave = true

  init(identity: SharedSessionLocalIdentity) {
    record = SharedSessionLocalIdentityRecord(
      acceptedIdentity: identity,
      pendingPublication: nil
    )
  }

  func loadRecord() throws -> SharedSessionLocalIdentityRecord? {
    lock.withLock { record }
  }

  func updateRecord(
    _ update: (SharedSessionLocalIdentityRecord?) throws -> SharedSessionLocalIdentityRecord?
  ) throws {
    try lock.withLock {
      let updated = try update(record)
      if shouldFailNextSave, updated?.acceptedIdentity != record?.acceptedIdentity {
        shouldFailNextSave = false
        throw Failure.save
      }
      record = updated
    }
  }
}

private final class PromotionFailingKeychain: @unchecked Sendable, KeychainStorage {
  enum Failure: Error {
    case write
  }

  private let lock = NSLock()
  private let backing = InMemoryKeychain()
  private var successfulWrites = 0
  var failWrites = true

  func set(_ data: Data, forKey key: String) throws {
    lock.lock()
    defer { lock.unlock() }
    if failWrites, successfulWrites >= 1 {
      throw Failure.write
    }
    try backing.set(data, forKey: key)
    successfulWrites += 1
  }

  func data(forKey key: String) throws -> Data? {
    try backing.data(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    try backing.deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try backing.hasItem(forKey: key)
  }
}

private final class UpdateFailingKeychain: @unchecked Sendable, KeychainStorage {
  enum Failure: Error {
    case update
  }

  private let lock = NSLock()
  private let backing = InMemoryKeychain()
  private var shouldFailNextExistingItemWrite = false

  func failNextExistingItemWrite() {
    lock.withLock {
      shouldFailNextExistingItemWrite = true
    }
  }

  func set(_ data: Data, forKey key: String) throws {
    try lock.withLock {
      if shouldFailNextExistingItemWrite,
         try backing.hasItem(forKey: key)
      {
        shouldFailNextExistingItemWrite = false
        throw Failure.update
      }
      try backing.set(data, forKey: key)
    }
  }

  func data(forKey key: String) throws -> Data? {
    try backing.data(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    try backing.deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try backing.hasItem(forKey: key)
  }
}
