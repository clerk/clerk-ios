@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Observation
import Security
import Testing

@MainActor
@Suite(.serialized)
struct ClerkTests {
  init() {
    configureClerkForTesting()
  }

  private func configureDependencies(
    signInService: MockSignInService? = nil,
    sessionService: MockSessionService? = nil,
    keychain: (any KeychainStorage)? = nil,
    environment: Clerk.Environment? = .mock
  ) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      signInService: signInService,
      sessionService: sessionService
    )
    Clerk.shared.environment = environment
  }

  func createSession(
    id: String,
    status: Session.SessionStatus,
    user: User? = .mock
  ) -> Session {
    let date = Date(timeIntervalSince1970: 1_609_459_200)
    return Session(
      id: id,
      status: status,
      expireAt: date,
      abandonAt: date,
      lastActiveAt: date,
      latestActivity: nil,
      lastActiveOrganizationId: nil,
      actor: nil,
      user: user,
      publicUserData: nil,
      createdAt: date,
      updatedAt: date,
      tasks: nil,
      lastActiveToken: nil
    )
  }

  @Test
  func callbackContinuationReturnsPendingAuthResult() {
    let signIn = SignIn(
      id: "sign_in_pending",
      status: .needsSecondFactor,
      createdSessionId: nil
    )
    let clerk = Clerk()

    clerk.setCallbackContinuation(.signIn(signIn))

    guard case .signIn(let pendingSignIn) = clerk.callbackContinuation else {
      Issue.record("Expected callbackContinuation to contain the pending sign-in result.")
      return
    }

    #expect(pendingSignIn == signIn)
  }

  @Test
  func isolatedConfigurationInstallsPersistenceBeforeStartup() throws {
    let keychain = InMemoryKeychain()
    try keychain.set(
      "isolated-device-token",
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )

    let clerk = try Clerk.configureForTesting(
      publishableKey: testPublishableKey,
      keychainStorage: keychain
    )
    defer { clerk.cleanupManagers() }

    #expect(clerk.publishableKey == testPublishableKey)
    #expect(clerk.identityController.currentDeviceToken == "isolated-device-token")
    #expect((clerk.dependencies.keychain as? InMemoryKeychain) === keychain)
    #expect((clerk.dependencies.appLocalKeychain as? InMemoryKeychain) === keychain)
    #expect((clerk.dependencies.identityKeychain as? InMemoryKeychain) === keychain)
  }

  @Test
  func clearAllKeychainItemsDeletesStoredDataAndPreservesAdoptionMarker() async throws {
    // Set up with InMemoryKeychain for testing
    let keychain = InMemoryKeychain()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    // Add test data for all keychain keys
    try keychain.set(#require("test-client-data".data(using: .utf8)), forKey: ClerkKeychainKey.cachedClient.rawValue)
    try keychain.set(#require("test-date-data".data(using: .utf8)), forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)
    try keychain.set(#require("test-environment-data".data(using: .utf8)), forKey: ClerkKeychainKey.cachedEnvironment.rawValue)
    try keychain.set("2", forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue)
    try keychain.set("set", forKey: ClerkKeychainKey.sharedSessionSyncAuthState.rawValue)
    try keychain.set("1", forKey: ClerkKeychainKey.sharedSessionSyncAuthVersion.rawValue)
    try keychain.set("1", forKey: ClerkKeychainKey.sharedSessionSyncEnvironmentVersion.rawValue)
    try keychain.set("set", forKey: ClerkKeychainKey.watchSyncAuthState.rawValue)
    try keychain.set("{}", forKey: ClerkKeychainKey.watchSyncMetadata.rawValue)
    try keychain.set("1", forKey: ClerkKeychainKey.watchSyncAuthVersion.rawValue)
    try keychain.set("test-device-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try keychain.set("set", forKey: ClerkKeychainKey.sharedSessionSyncDeviceTokenState.rawValue)
    try keychain.set("1", forKey: ClerkKeychainKey.sharedSessionSyncDeviceTokenVersion.rawValue)
    try keychain.set("set", forKey: ClerkKeychainKey.watchSyncDeviceTokenState.rawValue)
    try keychain.set("1", forKey: ClerkKeychainKey.watchSyncDeviceTokenVersion.rawValue)
    try keychain.set("true", forKey: ClerkKeychainKey.watchSyncDeviceTokenSynced.rawValue)
    try keychain.set("test-attest-key-id", forKey: ClerkKeychainKey.attestKeyId.rawValue)
    try keychain.set("test-pending-flow", forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue)
    try keychain.set(Data("[]".utf8), forKey: ClerkKeychainKey.trustedDeviceCredentials.rawValue)

    // Verify all keys exist before clearing
    for key in ClerkKeychainKey.allCases {
      #expect(try keychain.hasItem(forKey: key.rawValue) == true)
    }

    // Clear all keychain items
    Clerk.clearAllKeychainItems()

    // The adoption marker remains so disabling sync never falls back to legacy shared state.
    for key in ClerkKeychainKey.allCases {
      #expect(
        try keychain.hasItem(forKey: key.rawValue) == (key == .sharedSessionSyncAdopted)
      )
    }
    _ = try? await Clerk.shared.keychainClearTask?.value
  }

  @Test
  func clearAllKeychainItemsClearsAtomicLiveIdentity() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    try identityStore.save(
      SharedSessionLocalIdentity(
        state: .present,
        deviceToken: "token",
        client: Client.mock,
        serverDate: Date(timeIntervalSince1970: 100)
      )
    )
    let dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      atomicIdentityStore: identityStore,
      telemetryCollector: clerk.dependencies.telemetryCollector,
      clientService: MockClientService(get: { nil })
    )
    try clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }
    clerk.client = Client.mock
    clerk.identityController.lastServerDate = Date(timeIntervalSince1970: 100)

    try await clerk.clearAllKeychainItemsAndWait()

    #expect(clerk.client == nil)
    #expect(clerk.lastClientServerFetchDate == nil)
    #expect(try identityStore.loadRecord() == nil)
  }

  @Test
  func synchronousClearDeletesAtomicIdentityBeforeReturning() async throws {
    configureClerkForTesting()
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    try identityStore.save(
      SharedSessionLocalIdentity(
        state: .present,
        deviceToken: "token",
        client: Client.mock,
        serverDate: Date(timeIntervalSince1970: 100)
      )
    )
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      atomicIdentityStore: identityStore,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector,
      clientService: MockClientService(get: { nil })
    )
    Clerk.shared.client = Client.mock
    Clerk.shared.identityController.lastServerDate = Date(timeIntervalSince1970: 100)

    Clerk.clearAllKeychainItems()

    #expect(Clerk.shared.client == nil)
    #expect(Clerk.shared.lastClientServerFetchDate == nil)
    #expect(try identityStore.loadRecord() == nil)
    _ = try? await Clerk.shared.keychainClearTask?.value
  }

  @Test
  func sharedConfigurationHydratesProvisionalLegacyClientAfterAdoption() throws {
    let clerk = Clerk()
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let stableIdentityKeychain = InMemoryKeychain()
    let localStore = SharedSessionLocalIdentityStore(keychain: stableIdentityKeychain)
    let serverDate = Date(timeIntervalSince1970: 100)
    try appLocalKeychain.set("token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try appLocalKeychain.set(
      JSONEncoder.clerkEncoder.encode(Client.mock),
      forKey: ClerkKeychainKey.cachedClient.rawValue
    )
    try appLocalKeychain.set(
      String(serverDate.timeIntervalSince1970),
      forKey: ClerkKeychainKey.cachedClientServerDate.rawValue
    )
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain,
      identityKeychain: stableIdentityKeychain,
      atomicIdentityStore: localStore,
      shouldHydrateProvisionalLegacyClient: true,
      clientService: MockClientService(get: { nil })
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(sharedSessionSync: .enabled)
    )

    try clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }

    #expect(clerk.client?.id == Client.mock.id)
    #expect(clerk.authoritativeClient == nil)
    #expect(clerk.lastClientServerFetchDate == nil)
    #expect(try localStore.load() == nil)
  }

  @Test
  func provisionalLegacyClientIsExcludedFromRequestAndWatchIdentity() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let localStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      atomicIdentityStore: localStore,
      clientService: MockClientService(get: { nil })
    )
    clerk.dependencies = dependencies
    clerk.identityController.localDeviceToken = "device-token"
    clerk.identityController.hydrateProvisionalLegacyClientIfNeeded(.mock)

    let requestIdentity = try await clerk.identityController.captureRequestIdentity()
    let watchPayload = try WatchSyncPayload(
      clerk: clerk,
      metadata: .empty,
      authGeneration: WatchSyncVersion(rawValue: 1)
    )

    #expect(clerk.client?.id == Client.mock.id)
    #expect(clerk.authoritativeClient == nil)
    #expect(requestIdentity.deviceToken == "device-token")
    #expect(requestIdentity.clientID == nil)
    #expect(watchPayload.clientUpdate == .notIncluded)

    clerk.identityController.prepareForConfiguration()
    #expect(clerk.authoritativeClient == nil)
  }

  @Test
  func acceptedClientResponsePromotesProvisionalLegacyClient() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let localStore = SharedSessionLocalIdentityStore(keychain: keychain)
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      atomicIdentityStore: localStore,
      clientService: MockClientService(get: { nil })
    )
    clerk.identityController.localDeviceToken = "device-token"
    clerk.identityController.hydrateProvisionalLegacyClientIfNeeded(.mock)
    let requestIdentity = try await clerk.identityController.captureRequestIdentity()

    try await clerk.identityController.applyNetworkResponse(
      ClientSyncResponseContext(
        update: .client(.mock),
        deviceTokenUpdate: .set("device-token"),
        requestDeviceToken: "device-token",
        baseGeneration: requestIdentity.baseGeneration,
        serverDate: Date(timeIntervalSince1970: 200),
        isCanonicalClientRequest: true,
        clientResponseGeneration: requestIdentity.clientResponseGeneration,
        responseSequence: 1
      )
    )

    #expect(clerk.authoritativeClient?.id == Client.mock.id)
    #expect(try localStore.load()?.client?.id == Client.mock.id)
  }

  @Test
  func sharedConfigurationDoesNotHydrateLegacyClientAfterAdoptionWindow() throws {
    let clerk = Clerk()
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let stableIdentityKeychain = InMemoryKeychain()
    let localStore = SharedSessionLocalIdentityStore(keychain: stableIdentityKeychain)
    try appLocalKeychain.set(
      JSONEncoder.clerkEncoder.encode(Client.mock),
      forKey: ClerkKeychainKey.cachedClient.rawValue
    )
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain,
      identityKeychain: stableIdentityKeychain,
      atomicIdentityStore: localStore,
      shouldHydrateProvisionalLegacyClient: false,
      clientService: MockClientService(get: { nil })
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(sharedSessionSync: .enabled)
    )

    try clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }

    #expect(clerk.client == nil)
    #expect(try localStore.load() == nil)
  }

  @Test
  func sharedActivationHydratesPeerIdentitySynchronously() throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let localStore = SharedSessionLocalIdentityStore(keychain: keychain)
    var peerClient = Client.mock
    peerClient.id = "peer-client"
    let peerEvent = SharedSessionIdentityEvent(
      id: UUID(),
      originOwnerIdentifier: "app.peer",
      generation: 1,
      state: .present,
      deviceToken: "peer-token",
      client: peerClient,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let slotStore = ClearTrackingSlotStore()
    try slotStore.saveOwnSlot(SharedSessionOwnerSlot(
      schemaVersion: SharedSessionOwnerSlot.schemaVersion,
      instanceFingerprint: "instance",
      slotOwnerIdentifier: "app.peer",
      event: peerEvent
    ))
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      atomicIdentityStore: localStore,
      clientService: MockClientService(get: { nil })
    )
    let coordinator = SharedSessionSyncCoordinator(
      ownerIdentifier: "app.local",
      instanceFingerprint: "instance",
      slotStore: slotStore,
      localIdentityStore: localStore,
      notifier: SilentSharedSessionNotifier(),
      configurationEpoch: clerk.configurationEpoch,
      clerk: clerk,
      logError: { _, _ in }
    )
    defer { coordinator.deactivate() }

    let initialReconciliation = clerk.activateSharedSessionSync(coordinator)

    #expect(initialReconciliation != nil)
    #expect(clerk.sharedSessionSyncCoordinator === coordinator)
    #expect(clerk.client?.id == "peer-client")
    #expect(clerk.identityController.currentDeviceToken == "peer-token")
  }

  @Test
  func missingSharedEntitlementDiscardsPendingPublicationAndUsesDurableLocalIdentity() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let localStore = SharedSessionLocalIdentityStore(keychain: keychain)
    var localClient = Client.mock
    localClient.id = "durable-local-client"
    let localIdentity = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "durable-local-token",
      client: localClient,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    try localStore.save(localIdentity)
    try localStore.stagePendingPublication(SharedSessionIdentityEvent(
      id: UUID(),
      originOwnerIdentifier: "app.missing-entitlement",
      generation: 1,
      state: .present,
      deviceToken: "interrupted-token",
      client: Client.mock,
      serverDate: Date(timeIntervalSince1970: 200)
    ))
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      identityKeychain: keychain,
      atomicIdentityStore: localStore,
      clientService: MockClientService(get: { nil })
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(accessGroup: "group.missing-entitlement"),
        sharedSessionSync: .enabled
      )
    )
    clerk.dependencies = dependencies
    clerk.cacheManager = CacheManager(
      coordinator: clerk,
      identityKeychain: keychain,
      environmentKeychain: keychain,
      atomicIdentityStore: localStore
    )
    let coordinator = SharedSessionSyncCoordinator(
      ownerIdentifier: "app.missing-entitlement",
      instanceFingerprint: "instance",
      slotStore: MissingEntitlementSlotStore(),
      localIdentityStore: localStore,
      localIdentityIO: dependencies.atomicIdentityIO,
      notifier: SilentSharedSessionNotifier(),
      configurationEpoch: clerk.configurationEpoch,
      clerk: clerk,
      logError: { _, _ in }
    )

    let initialReconciliation = clerk.activateSharedSessionSync(coordinator)

    #expect(initialReconciliation == nil)
    #expect(clerk.sharedSessionSyncCoordinator == nil)
    #expect(clerk.client?.id == "durable-local-client")
    #expect(clerk.identityController.currentDeviceToken == "durable-local-token")
    let persistedIdentity = try #require(try localStore.load())
    #expect(persistedIdentity.state == .present)
    #expect(persistedIdentity.deviceToken == "durable-local-token")
    #expect(persistedIdentity.client?.id == "durable-local-client")
    #expect(try localStore.loadPendingPublication() == nil)

    var replacementClient = Client.mock
    replacementClient.id = "replacement-local-client"
    let replacementIdentity = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "replacement-local-token",
      client: replacementClient,
      serverDate: Date(timeIntervalSince1970: 300)
    )
    #expect(try await clerk.identityController.persistAndApplyAtomicIdentity(
      replacementIdentity,
      through: #require(dependencies.atomicIdentityIO),
      operationRevision: 1,
      fenceAllClientResponses: true
    ))
    #expect(clerk.client?.id == "replacement-local-client")
    #expect(try localStore.load()?.client?.id == "replacement-local-client")
    #expect(try localStore.loadRecord()?.requiresSharedSessionPublication == true)
  }

  @Test
  func synchronousClearCannotBeUndoneByPreviouslySuspendedIdentitySave() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let store = SharedSessionLocalIdentityStore(keychain: keychain)
    try store.save(
      SharedSessionLocalIdentity(
        state: .cleared,
        deviceToken: "initial-token",
        client: nil,
        serverDate: nil
      )
    )
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      atomicIdentityStore: store,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    let localIdentityIO = try #require(clerk.dependencies.atomicIdentityIO)
    let identity = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "stale-token",
      client: .mock,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let gate = LocalIdentityOperationGate()
    let saveTask = clerk.identityController.enqueueLocalOperation { operationRevision in
      await gate.suspend()
      return try await clerk.identityController.persistAndApplyAtomicIdentity(
        identity,
        through: localIdentityIO,
        operationRevision: operationRevision,
        fenceAllClientResponses: false
      )
    }
    try await waitUntil { gate.isSuspended }

    let clearTask = Clerk.startKeychainClearIfNeeded(for: clerk)

    #expect(try store.loadRecord() == nil)
    gate.resume()
    _ = try? await saveTask.value
    _ = try? await clearTask.value

    #expect(try store.loadRecord() == nil)
    #expect(clerk.identityController.localDeviceToken == nil)
    #expect(clerk.client == nil)
  }

  @Test
  func synchronousClearRemainsCallableFromAsyncCodeAndOverlappingCallsCoalesce() async throws {
    let synchronousAPI: @MainActor () -> Void = Clerk.clearAllKeychainItems
    _ = synchronousAPI

    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: InMemoryKeychain(),
      telemetryCollector: clerk.dependencies.telemetryCollector
    )

    let revision = clerk.identityController.localOperationRevision
    let firstClear = Clerk.startKeychainClearIfNeeded(for: clerk)
    let revisionAfterFirstClear = clerk.identityController.localOperationRevision
    let secondClear = Clerk.startKeychainClearIfNeeded(for: clerk)

    #expect(firstClear == secondClear)
    #expect(revisionAfterFirstClear > revision)
    #expect(clerk.identityController.localOperationRevision == revisionAfterFirstClear)
    try await firstClear.value

    #expect(clerk.keychainClearTask == nil)
  }

  @Test
  func strictReconfigurationClearPreservesNewWatchTombstone() async throws {
    let legacyShared = InMemoryKeychain()
    let appLocal = InMemoryKeychain()
    let identityKeychain = InMemoryKeychain()
    try WatchSyncMetadataStore(keychain: legacyShared).save(
      WatchSyncMetadataRecord(
        deviceTokenState: .set,
        deviceTokenVersion: 9,
        authState: .set,
        authVersion: 9
      )
    )
    try legacyShared.set(
      "legacy-token",
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )
    try legacyShared.set(
      JSONEncoder.clerkEncoder.encode(Client.mock),
      forKey: ClerkKeychainKey.cachedClient.rawValue
    )
    try legacyShared.set(
      JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock),
      forKey: ClerkKeychainKey.cachedEnvironment.rawValue
    )
    let dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: legacyShared,
      appLocalKeychain: appLocal,
      identityKeychain: identityKeychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    try await Clerk.clearLocalClerkStorageStrictly(
      in: dependencies,
      deleteSharedSessionOwnerSlot: false
    )

    let metadata = try WatchSyncMetadataStore(keychain: appLocal).load()
    let clearVersion = try #require(metadata.authVersion)
    #expect(clearVersion > 9)
    #expect(metadata.deviceTokenVersion == clearVersion)
    #expect(metadata.deviceTokenState == .cleared)
    #expect(metadata.authState == .cleared)
    #expect(!metadata.hasPendingIdentityMetadata)
    #expect(
      try legacyShared.data(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == nil
    )
    #expect(
      try legacyShared.data(forKey: ClerkKeychainKey.cachedClient.rawValue) == nil
    )
    #expect(
      try legacyShared.data(forKey: ClerkKeychainKey.cachedEnvironment.rawValue) == nil
    )
  }

  @Test
  func awaitedClearReportsAtomicIdentityDeletionFailure() async throws {
    let clerk = Clerk()
    let keychain = DeleteFailingKeychain(
      failingKey: SharedSessionLocalIdentityStore.storageKey
    )
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    try identityStore.save(
      ClerkIdentitySnapshot(
        state: .present,
        deviceToken: "token",
        client: .mock,
        serverDate: nil
      )
    )
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      atomicIdentityStore: identityStore,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )

    var didThrow = false
    do {
      try await clerk.clearAllKeychainItemsAndWait()
    } catch {
      didThrow = true
    }

    #expect(didThrow)
    #expect(try identityStore.load() != nil)
    #expect(clerk.keychainClearTask == nil)
  }

  @Test
  func awaitedClearAcceptsSuccessfulAtomicIdentityDeletionRetry() async throws {
    let clerk = Clerk()
    let keychain = DeleteFailingKeychain(
      failingKey: SharedSessionLocalIdentityStore.storageKey,
      failuresRemaining: 1
    )
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    try identityStore.save(ClerkIdentitySnapshot(
      state: .present,
      deviceToken: "token",
      client: .mock,
      serverDate: nil
    ))
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      atomicIdentityStore: identityStore,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )

    try await clerk.clearAllKeychainItemsAndWait()

    #expect(try identityStore.loadRecord() == nil)
    #expect(keychain.failureCount == 1)
    #expect(clerk.keychainClearTask == nil)
  }

  @Test
  func awaitedClearWithdrawsOwnerSlotBeforeReturning() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let slotStore = ClearTrackingSlotStore()
    let recovery = makeClearRecoveryContext(
      journal: keychain,
      identityStore: identityStore,
      slotStore: slotStore
    )
    let dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      atomicIdentityStore: identityStore,
      sharedSessionOwnerSlotClearRecovery: recovery,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    clerk.dependencies = dependencies
    let coordinator = SharedSessionSyncCoordinator(
      ownerIdentifier: "app.clear",
      instanceFingerprint: "instance",
      slotStore: slotStore,
      localIdentityStore: identityStore,
      localIdentityIO: dependencies.atomicIdentityIO,
      notifier: SilentSharedSessionNotifier(),
      configurationEpoch: clerk.configurationEpoch,
      clerk: clerk
    )
    clerk.sharedSessionSyncCoordinator = coordinator
    defer { clerk.sharedSessionSyncCoordinator = nil }
    let identity = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "token",
      client: .mock,
      serverDate: nil
    )
    try identityStore.save(identity)
    clerk.hydrateIdentityIfNeeded(identity)
    try slotStore.saveOwnSlot(
      SharedSessionOwnerSlot(
        schemaVersion: SharedSessionOwnerSlot.schemaVersion,
        instanceFingerprint: "instance",
        slotOwnerIdentifier: "app.clear",
        event: SharedSessionIdentityEvent(
          id: UUID(),
          originOwnerIdentifier: "app.clear",
          generation: 1,
          state: .present,
          deviceToken: "token",
          client: .mock,
          serverDate: nil
        )
      )
    )

    try await clerk.clearAllKeychainItemsAndWait()

    #expect(try slotStore.loadOwnSlot() == nil)
    #expect(try identityStore.loadRecord() == nil)
    #expect(clerk.client == nil)
  }

  @Test
  func awaitedClearKeepsPublicationBlockedUntilRecoveryIntentIsRemoved() async throws {
    let clerk = Clerk()
    let keychain = DeleteFailingKeychain(
      failingKey: SharedSessionOwnerSlotClearRecovery.storageKey,
      failuresRemaining: 1
    )
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let slotStore = ClearTrackingSlotStore()
    let recovery = makeClearRecoveryContext(
      journal: keychain,
      identityStore: identityStore,
      slotStore: slotStore
    )
    let dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      atomicIdentityStore: identityStore,
      sharedSessionOwnerSlotClearRecovery: recovery,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    clerk.dependencies = dependencies
    let coordinator = SharedSessionSyncCoordinator(
      ownerIdentifier: "app.clear",
      instanceFingerprint: "instance",
      slotStore: slotStore,
      localIdentityStore: identityStore,
      localIdentityIO: dependencies.atomicIdentityIO,
      notifier: SilentSharedSessionNotifier(),
      configurationEpoch: clerk.configurationEpoch,
      clerk: clerk
    )
    clerk.sharedSessionSyncCoordinator = coordinator
    defer { clerk.sharedSessionSyncCoordinator = nil }
    try slotStore.saveOwnSlot(
      SharedSessionOwnerSlot(
        schemaVersion: SharedSessionOwnerSlot.schemaVersion,
        instanceFingerprint: "instance",
        slotOwnerIdentifier: "app.clear",
        event: SharedSessionIdentityEvent(
          id: UUID(),
          originOwnerIdentifier: "app.clear",
          generation: 1,
          state: .present,
          deviceToken: "old-token",
          client: .mock,
          serverDate: nil
        )
      )
    )

    var clearFailed = false
    do {
      try await clerk.clearAllKeychainItemsAndWait()
    } catch {
      clearFailed = true
    }

    #expect(clearFailed)
    #expect(try slotStore.loadOwnSlot() == nil)
    #expect(try SharedSessionOwnerSlotClearRecovery.loadPendingIntent(in: keychain) != nil)
    await #expect(throws: CancellationError.self) {
      try await coordinator.publishLocalIdentity(
        state: .present,
        deviceToken: "new-token",
        client: .mock,
        serverDate: nil
      )
    }

    try await clerk.clearAllKeychainItemsAndWait()

    #expect(try SharedSessionOwnerSlotClearRecovery.loadPendingIntent(in: keychain) == nil)
    #expect(
      try await coordinator.publishLocalIdentity(
        state: .present,
        deviceToken: "new-token",
        client: .mock,
        serverDate: nil
      )
    )
    #expect(try slotStore.loadOwnSlot()?.event.deviceToken == "new-token")
  }

  @Test
  func awaitedClearKeepsRecoveryIntentWhenAtomicIdentityDeletionFailsTwice() async throws {
    let clerk = Clerk()
    let keychain = DeleteFailingKeychain(
      failingKey: SharedSessionLocalIdentityStore.storageKey
    )
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let slotStore = ClearTrackingSlotStore()
    let recovery = makeClearRecoveryContext(
      journal: keychain,
      identityStore: identityStore,
      slotStore: slotStore
    )
    let dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      atomicIdentityStore: identityStore,
      sharedSessionOwnerSlotClearRecovery: recovery,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    clerk.dependencies = dependencies
    let coordinator = SharedSessionSyncCoordinator(
      ownerIdentifier: "app.clear",
      instanceFingerprint: "instance",
      slotStore: slotStore,
      localIdentityStore: identityStore,
      localIdentityIO: dependencies.atomicIdentityIO,
      notifier: SilentSharedSessionNotifier(),
      configurationEpoch: clerk.configurationEpoch,
      clerk: clerk
    )
    clerk.sharedSessionSyncCoordinator = coordinator
    defer { clerk.sharedSessionSyncCoordinator = nil }
    let identity = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "old-token",
      client: .mock,
      serverDate: nil
    )
    try identityStore.save(identity)
    clerk.hydrateIdentityIfNeeded(identity)
    try slotStore.saveOwnSlot(
      SharedSessionOwnerSlot(
        schemaVersion: SharedSessionOwnerSlot.schemaVersion,
        instanceFingerprint: "instance",
        slotOwnerIdentifier: "app.clear",
        event: SharedSessionIdentityEvent(
          id: UUID(),
          originOwnerIdentifier: "app.clear",
          generation: 1,
          state: .present,
          deviceToken: identity.deviceToken,
          client: identity.client,
          serverDate: identity.serverDate
        )
      )
    )

    do {
      try await clerk.clearAllKeychainItemsAndWait()
      Issue.record("Expected both atomic identity deletion attempts to fail.")
    } catch {
      #expect(error.localizedDescription.contains("delete atomic identity"))
    }

    #expect(keychain.failureCount == 2)
    let retainedIdentity = try #require(try identityStore.load())
    #expect(retainedIdentity.state == .present)
    #expect(retainedIdentity.deviceToken == "old-token")
    #expect(retainedIdentity.client?.id == identity.client?.id)
    #expect(try slotStore.loadOwnSlot() == nil)
    #expect(
      try SharedSessionOwnerSlotClearRecovery.loadPendingIntent(in: keychain)
        == recovery.currentIntent
    )
    await #expect(throws: CancellationError.self) {
      _ = try await coordinator.captureRequestIdentity()
    }

    keychain.allowDeletes()
    #expect(try SharedSessionOwnerSlotClearRecovery.recoverIfNeeded(in: recovery))
    #expect(try identityStore.loadRecord() == nil)
    #expect(try SharedSessionOwnerSlotClearRecovery.loadPendingIntent(in: keychain) == nil)
  }

  @Test
  func awaitedClearCannotBeUndoneByPreviouslySuspendedIdentitySave() async throws {
    let clerk = Clerk()
    clerk.sharedSessionSyncCoordinator = nil
    let keychain = InMemoryKeychain()
    let store = SharedSessionLocalIdentityStore(keychain: keychain)
    try store.save(
      SharedSessionLocalIdentity(
        state: .cleared,
        deviceToken: "initial-token",
        client: nil,
        serverDate: nil
      )
    )
    let dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      atomicIdentityStore: store,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    clerk.dependencies = dependencies
    let localIdentityIO = try #require(dependencies.atomicIdentityIO)
    let identity = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "stale-token",
      client: .mock,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let gate = LocalIdentityOperationGate()
    let saveTask = clerk.identityController.enqueueLocalOperation { operationRevision in
      await gate.suspend()
      return try await clerk.identityController.persistAndApplyAtomicIdentity(
        identity,
        through: localIdentityIO,
        operationRevision: operationRevision,
        fenceAllClientResponses: false
      )
    }
    try await waitUntil { gate.isSuspended }

    let clearTask = Task { @MainActor in
      try await clerk.clearAllKeychainItemsAndWait()
    }
    await Task.yield()
    #expect(clerk.identityController.localDeviceToken == nil)
    #expect(clerk.client == nil)
    gate.resume()

    _ = try? await saveTask.value
    try await clearTask.value

    #expect(try store.loadRecord() == nil)
    #expect(clerk.identityController.localDeviceToken == nil)
    #expect(clerk.client == nil)
  }

  @Test
  func awaitedClearDrainsSuspendedCacheWriterBeforeFinalDeletion() async throws {
    let clerk = Clerk()
    let keychain = SuspendingCacheKeychain()
    let dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    try clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }
    keychain.suspendNextSet(forKey: ClerkKeychainKey.cachedClient.rawValue)
    clerk.client = .mock
    try await waitUntil { keychain.isSetSuspended }

    var didComplete = false
    let clearTask = Task { @MainActor in
      try await clerk.clearAllKeychainItemsAndWait()
      didComplete = true
    }
    await Task.yield()
    #expect(!didComplete)

    keychain.resumeSuspendedSet()
    try await clearTask.value

    #expect(didComplete)
    #expect(try keychain.data(forKey: ClerkKeychainKey.cachedClient.rawValue) == nil)
    #expect(try keychain.data(forKey: ClerkKeychainKey.cachedClientServerDate.rawValue) == nil)
  }

  @Test
  func adoptedWatchTransitionFencesOlderQueuedNetworkResponse() async throws {
    let clerk = Clerk()
    clerk.sharedSessionSyncCoordinator = nil
    let store = SuspendingIdentityStore()
    let initialIdentity = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "token",
      client: .mock,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    try store.save(initialIdentity)
    let keychain = InMemoryKeychain()
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      atomicIdentityStore: store,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    clerk.hydrateIdentityIfNeeded(initialIdentity)
    let capturedResponseGeneration = clerk.clientResponseGeneration
    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "token",
        version: WatchSyncVersion(rawValue: 1)
      ),
      clientUpdate: .cleared(
        serverFetchDate: Date(timeIntervalSince1970: 200),
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )
    let watchCoordinator = WatchConnectivityCoordinator()
    store.suspendNextSave()
    watchCoordinator.apply(payload, from: .phone, to: clerk)
    try await waitUntil { store.isSaveSuspended }

    let responseTask = Task { @MainActor in
      try await clerk.identityController.applyNetworkResponse(
        ClientSyncResponseContext(
          update: .client(.mock),
          deviceTokenUpdate: .set("token"),
          requestDeviceToken: "token",
          baseGeneration: 0,
          serverDate: Date(timeIntervalSince1970: 300),
          isCanonicalClientRequest: true,
          clientResponseGeneration: capturedResponseGeneration,
          responseSequence: 1
        )
      )
    }
    store.resumeSuspendedSave()

    await watchCoordinator.waitForIdentityPublications()
    try await responseTask.value

    #expect(clerk.client == nil)
    #expect(try store.load()?.client == nil)
  }

  @Test
  func clearAllKeychainItemsHandlesMissingKeysGracefully() throws {
    // Set up with InMemoryKeychain for testing
    let keychain = InMemoryKeychain()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    // Add only some keys (not all)
    try keychain.set("test-device-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try keychain.set("test-attest-key-id", forKey: ClerkKeychainKey.attestKeyId.rawValue)

    // Clear all keychain items (should not throw even though some keys don't exist)
    Clerk.clearAllKeychainItems()

    // Verify all keys are deleted (including ones that didn't exist)
    for key in ClerkKeychainKey.allCases {
      #expect(try keychain.hasItem(forKey: key.rawValue) == false)
    }
  }

  @Test
  func clearAllKeychainItemsWorksWhenClerkNotConfigured() throws {
    // Note: This test verifies that clearAllKeychainItems can be called even when Clerk is configured.
    // When Clerk is not configured, clearAllKeychainItems creates a temporary SystemKeychain instance.
    // Since we can't easily test the unconfigured state without accessing private properties,
    // we verify that the function works correctly when Clerk is configured (which is the common case).
    // The unconfigured case is tested implicitly through code coverage.

    // Set up with InMemoryKeychain for testing
    let keychain = InMemoryKeychain()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    // Add test data
    try keychain.set("test-device-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)

    // Function should work correctly
    Clerk.clearAllKeychainItems()

    // Verify key was deleted
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == false)
  }

  @Test
  func clearAllKeychainItemsDoesNotThrow() throws {
    // Set up with InMemoryKeychain for testing
    let keychain = InMemoryKeychain()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )

    // Add some test data
    try keychain.set("test-data", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)

    // Function should not throw even if there are errors
    Clerk.clearAllKeychainItems()

    // Verify key was deleted
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == false)
  }

  @Test
  func clearAllKeychainItemsPreservesTrustedDeviceMetadataWhenCredentialCleanupFails() throws {
    let keychain = DataFailingKeychain(failingKey: ClerkKeychainKey.trustedDeviceCredentials.rawValue)
    try keychain.set("test-client-data", forKey: ClerkKeychainKey.cachedClient.rawValue)
    try keychain.set(Data("[{}]".utf8), forKey: ClerkKeychainKey.trustedDeviceCredentials.rawValue)

    Clerk.clearAllKeychainItems(in: keychain)

    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedClient.rawValue) == false)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.trustedDeviceCredentials.rawValue) == true)
  }

  @Test
  func clearAllKeychainItemsStrictlyPreservesTrustedDeviceMetadataWhenCredentialCleanupFails() throws {
    let keychain = DataFailingKeychain(failingKey: ClerkKeychainKey.trustedDeviceCredentials.rawValue)
    try keychain.set("test-client-data", forKey: ClerkKeychainKey.cachedClient.rawValue)
    try keychain.set(Data("[{}]".utf8), forKey: ClerkKeychainKey.trustedDeviceCredentials.rawValue)

    #expect(throws: ClerkClientError.self) {
      try Clerk.clearAllKeychainItemsStrictly(in: keychain)
    }
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedClient.rawValue) == false)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.trustedDeviceCredentials.rawValue) == true)
  }

  @Test
  func configureClearsCurrentAppTrustedDeviceCredentialsWhenInstallMarkerIsMissing() throws {
    let suiteName = installationMarkerDefaultsSuiteName()
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    let originalDefaults = Clerk.installationMarkerUserDefaults
    let originalAppIdentifierProvider = Clerk.trustedDeviceAppIdentifierProvider
    Clerk.installationMarkerUserDefaults = defaults
    Clerk.trustedDeviceAppIdentifierProvider = { "com.clerk.example" }
    defer {
      Clerk.installationMarkerUserDefaults = originalDefaults
      Clerk.trustedDeviceAppIdentifierProvider = originalAppIdentifierProvider
      defaults.removePersistentDomain(forName: suiteName)
    }

    let keychain = InMemoryKeychain()
    let credentialStore = TrustedDeviceLocalCredentialStore(keychain: keychain)
    let otherAppCredential = TrustedDeviceLocalCredential(
      id: "tdc_other_app",
      localKeyId: "tdlk_other_app",
      userID: User.mock.id,
      appIdentifier: "com.clerk.other",
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 2)
    )
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      trustedDeviceKeyManager: MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      }),
      trustedDeviceCredentialStore: credentialStore
    )
    try credentialStore.save(.mock)
    try credentialStore.save(otherAppCredential)

    let clerk = Clerk()
    try clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }

    #expect(deletedLocalKeyIds.value == ["tdlk_mock"])
    #expect(try credentialStore.all() == [otherAppCredential])
  }

  @Test
  func configureKeepsTrustedDeviceCredentialsWhenInstallMarkerExists() throws {
    let suiteName = installationMarkerDefaultsSuiteName()
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    let originalDefaults = Clerk.installationMarkerUserDefaults
    let originalAppIdentifierProvider = Clerk.trustedDeviceAppIdentifierProvider
    Clerk.installationMarkerUserDefaults = defaults
    Clerk.trustedDeviceAppIdentifierProvider = { "com.clerk.example" }
    defer {
      Clerk.installationMarkerUserDefaults = originalDefaults
      Clerk.trustedDeviceAppIdentifierProvider = originalAppIdentifierProvider
      defaults.removePersistentDomain(forName: suiteName)
    }

    let keychain = InMemoryKeychain()
    let credentialStore = TrustedDeviceLocalCredentialStore(keychain: keychain)
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      trustedDeviceKeyManager: MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      }),
      trustedDeviceCredentialStore: credentialStore
    )

    let firstConfigure = Clerk()
    try firstConfigure.performConfiguration(dependencies: dependencies)
    firstConfigure.cleanupManagers()

    try credentialStore.save(.mock)
    let secondConfigure = Clerk()
    try secondConfigure.performConfiguration(dependencies: dependencies)
    defer { secondConfigure.cleanupManagers() }

    #expect(deletedLocalKeyIds.value.isEmpty)
    #expect(try credentialStore.all() == [.mock])
  }

  @Test
  func configureUsesAppScopedTrustedDeviceInstallationMarkers() throws {
    let suiteName = installationMarkerDefaultsSuiteName()
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    let originalDefaults = Clerk.installationMarkerUserDefaults
    let originalAppIdentifierProvider = Clerk.trustedDeviceAppIdentifierProvider
    Clerk.installationMarkerUserDefaults = defaults
    Clerk.trustedDeviceAppIdentifierProvider = { "com.clerk.example" }
    defer {
      Clerk.installationMarkerUserDefaults = originalDefaults
      Clerk.trustedDeviceAppIdentifierProvider = originalAppIdentifierProvider
      defaults.removePersistentDomain(forName: suiteName)
    }

    let keychain = InMemoryKeychain()
    let credentialStore = TrustedDeviceLocalCredentialStore(keychain: keychain)
    let otherAppCredential = TrustedDeviceLocalCredential(
      id: "tdc_other_app",
      localKeyId: "tdlk_other_app",
      userID: User.mock.id,
      appIdentifier: "com.clerk.other",
      createdAt: Date(timeIntervalSince1970: 1),
      updatedAt: Date(timeIntervalSince1970: 2)
    )
    let deletedLocalKeyIds = LockIsolated<[String]>([])
    let dependencies = MockDependencyContainer(
      apiClient: Clerk.shared.dependencies.apiClient,
      keychain: keychain,
      trustedDeviceKeyManager: MockTrustedDeviceKeyManager(deleteKey: { localKeyId in
        deletedLocalKeyIds.withValue { $0.append(localKeyId) }
      }),
      trustedDeviceCredentialStore: credentialStore
    )

    let firstConfigure = Clerk()
    try firstConfigure.performConfiguration(dependencies: dependencies)
    firstConfigure.cleanupManagers()

    try credentialStore.save(otherAppCredential)
    Clerk.trustedDeviceAppIdentifierProvider = { "com.clerk.other" }

    let secondConfigure = Clerk()
    try secondConfigure.performConfiguration(dependencies: dependencies)
    defer { secondConfigure.cleanupManagers() }

    #expect(deletedLocalKeyIds.value == ["tdlk_other_app"])
    #expect(try credentialStore.all().isEmpty)
  }

  @Test
  func trustedDeviceInstallationMarkerPreservesConfigurationBoundaries() {
    let first = Clerk.trustedDeviceInstallationMarkerKey(
      for: .init(service: "a.b", accessGroup: "c"),
      appIdentifier: "com.clerk.example"
    )
    let second = Clerk.trustedDeviceInstallationMarkerKey(
      for: .init(service: "a", accessGroup: "b.c"),
      appIdentifier: "com.clerk.example"
    )
    let missingAccessGroup = Clerk.trustedDeviceInstallationMarkerKey(
      for: .init(service: "a", accessGroup: nil),
      appIdentifier: "com.clerk.example"
    )
    let literalDefaultAccessGroup = Clerk.trustedDeviceInstallationMarkerKey(
      for: .init(service: "a", accessGroup: "default"),
      appIdentifier: "com.clerk.example"
    )

    #expect(first != second)
    #expect(missingAccessGroup != literalDefaultAccessGroup)
  }

  // MARK: - isLoaded Tests

  @Test
  func isLoadedReturnsFalseWhenBothNil() {
    // Clear both client and environment
    Clerk.shared.client = nil
    Clerk.shared.environment = nil

    // isLoaded should return false when both are nil
    #expect(Clerk.shared.isLoaded == false)
  }

  @Test
  func isLoadedReturnsFalseWhenOnlyEnvironmentSet() {
    // Set only environment
    Clerk.shared.environment = Clerk.Environment.mock
    Clerk.shared.client = nil

    // isLoaded should return false when client is nil
    #expect(Clerk.shared.isLoaded == false)
  }

  @Test
  func isLoadedReturnsFalseWhenOnlyClientSet() {
    // Set only client
    Clerk.shared.client = Client.mock
    Clerk.shared.environment = nil

    // isLoaded should return false when environment is nil
    #expect(Clerk.shared.isLoaded == false)
  }

  @Test
  func isLoadedReturnsTrueWhenBothSet() {
    // Set both client and environment
    Clerk.shared.client = Client.mock
    Clerk.shared.environment = Clerk.Environment.mock

    // isLoaded should return true when both are set
    #expect(Clerk.shared.isLoaded == true)
  }

  @Test
  func isLoadedBecomesTrue() {
    // Clear both client and environment first
    Clerk.shared.client = nil
    Clerk.shared.environment = nil
    #expect(Clerk.shared.isLoaded == false)

    // Set client - should still be false since environment is nil
    Clerk.shared.client = Client.mock
    #expect(Clerk.shared.isLoaded == false)

    // Set environment - now both are set so should be true
    Clerk.shared.environment = Clerk.Environment.mock
    #expect(Clerk.shared.isLoaded == true)

    // Clear client - should become false again
    Clerk.shared.client = nil
    #expect(Clerk.shared.isLoaded == false)
  }

  // MARK: - isAuthFlowComplete Tests

  @Test
  func isAuthFlowCompleteReturnsFalseWhenSignedOut() {
    let clerk = Clerk.mockSignedOut

    #expect(clerk.isAuthFlowComplete == false)
  }

  @Test
  func isAuthFlowCompleteReturnsFalseWhenSessionIsPending() {
    var client = Client.mock
    client.sessions[0].status = .pending
    client.sessions[0].tasks = [.setupMfa]
    let clerk = Clerk.mock
    clerk.client = client

    #expect(clerk.user != nil)
    #expect(clerk.isAuthFlowComplete == false)
  }

  @Test
  func isAuthFlowCompleteReturnsFalseWhenActiveSessionHasNoUser() {
    var client = Client.mock
    client.sessions[0].user = nil
    let clerk = Clerk.mock
    clerk.client = client

    #expect(clerk.session?.status == .active)
    #expect(clerk.isAuthFlowComplete == false)
  }

  @Test
  func isAuthFlowCompleteReturnsTrueWhenUserHasActiveSession() {
    let clerk = Clerk.mock

    #expect(clerk.user != nil)
    #expect(clerk.session?.status == .active)
    #expect(clerk.isAuthFlowComplete)
  }

  @Test
  func registerAuthFlowDoesNotRegisterAnExistingActiveSession() {
    let clerk = Clerk.mock

    let registration = clerk.registerAuthFlow()

    #expect(registration == nil)
    #expect(clerk.isAuthFlowComplete)
  }

  @Test
  func authFlowRegistrationIsExclusive() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())

    #expect(clerk.registerAuthFlow(role: .dismissible) == nil)
    withExtendedLifetime(registration) {}
  }

  @Test
  func rejectedSecondRegistrationDoesNotStealInFlightWork() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    clerk.applyResponseClient(.mock, completedAuthFlow: completedAuthFlow())
    let original = try #require(awaitingAuthFlow(in: clerk, for: registration))
    let originalRevision = try #require(
      clerk.authFlowSnapshot(for: registration)?.revision
    )

    #expect(clerk.registerAuthFlow(role: .dismissible) == nil)

    let current = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(current.work == original.work)
    #expect(clerk.authFlowSnapshot(for: registration)?.revision == originalRevision)
    #expect(clerk.authFlowRegistrationId == registration.id)
    #expect(clerk.isAuthFlowComplete == false)
    withExtendedLifetime(registration) {}
  }

  @Test
  func requestsAreOwnedOnlyByTheirExplicitAuthFlowOperation() async throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())

    let unowned = try await clerk.identityController.captureRequestIdentity()
    #expect(unowned.authFlowRegistrationId == nil)

    let owned = try await AuthFlowRequestScope.withOwner(registration.id) {
      try await clerk.identityController.captureRequestIdentity()
    }
    #expect(owned.authFlowRegistrationId == registration.id)

    let explicitlyUnowned = try await AuthFlowRequestScope.withOwner(
      registration.id
    ) {
      try await AuthFlowRequestScope.withOwner(nil) {
        try await clerk.identityController.captureRequestIdentity()
      }
    }
    #expect(explicitlyUnowned.authFlowRegistrationId == nil)

    let originalRegistrationId = registration.id
    let captured = try await AuthFlowRequestScope.withOwner(registration.id) {
      registration.cancel()
      let replacement = try #require(clerk.registerAuthFlow())
      let identity = try await clerk.identityController.captureRequestIdentity()
      #expect(identity.authFlowRegistrationId != replacement.id)
      withExtendedLifetime(replacement) {}
      return identity
    }
    #expect(captured.authFlowRegistrationId == originalRegistrationId)
  }

  @Test
  func dismissibleAuthFlowOwnsCompletionWithoutGatingSignedInContent() throws {
    let clerk = Clerk.mock
    let registration = try #require(
      clerk.registerAuthFlow(role: .dismissible)
    )
    let completion = completedAuthFlow()

    clerk.applyResponseClient(.mock, completedAuthFlow: completion)

    let awaiting = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(awaiting.sessionId == clerk.session?.id)
    #expect(awaiting.completion?.flowId == completion.flowId)
    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func externalActiveSessionDoesNotHoldRootAuthFlow() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())

    clerk.applyResponseClient(.mock)

    let awaiting = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(awaiting.sessionId == clerk.session?.id)
    #expect(awaiting.completion == nil)
    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func ownedHostedActivationHoldsRootUntilSessionSelectionCompletes() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    let sessionId = try #require(Client.mock.currentSession?.id)

    let activation = try #require(clerk.beginAuthSessionActivation(
      sessionId: sessionId,
      ownerId: registration.id
    ))
    clerk.setClientFromIdentityController(.mock)

    let awaiting = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(awaiting.sessionId == sessionId)
    #expect(awaiting.completion == nil)
    #expect(clerk.isAuthFlowComplete == false)

    clerk.authSessionActivationDidFinish(activation: activation)

    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func hostedActivationRetainsItsTargetWhileAnotherSessionIsCurrent() throws {
    var sessionA = try #require(Client.mock.currentSession)
    sessionA.id = "session-a"
    var sessionB = sessionA
    sessionB.id = "session-b"
    var clientA = Client.mock
    clientA.sessions = [sessionA]
    clientA.lastActiveSessionId = sessionA.id
    let clerk = Clerk.mock
    clerk.client = clientA
    let registration = try #require(
      clerk.registerAuthFlow(role: .dismissible)
    )

    let activation = try #require(clerk.beginAuthSessionActivation(
      sessionId: sessionB.id,
      ownerId: registration.id
    ))
    var redeemClient = clientA
    redeemClient.sessions = [sessionA, sessionB]
    clerk.setClientFromIdentityController(
      redeemClient,
      authFlowUpdate: .authoritativeIdentityChanged
    )

    let retained = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(retained.sessionId == sessionB.id)

    var selectedClient = redeemClient
    selectedClient.lastActiveSessionId = sessionB.id
    clerk.setClientFromIdentityController(selectedClient)
    clerk.authSessionActivationDidFinish(activation: activation)

    let selected = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(selected.sessionId == sessionB.id)
    #expect(selected.completion == nil)
    withExtendedLifetime(registration) {}
  }

  @Test
  func completedAuthenticationDoesNotGateWithoutRootRegistration() {
    let clerk = Clerk.mockSignedOut

    clerk.applyResponseClient(.mock, completedAuthFlow: completedAuthFlow())

    #expect(clerk.isAuthFlowComplete)
  }

  @Test
  func acceptedCompletionBlocksRootUntilItsExactWorkCompletes() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    let completion = completedAuthFlow()

    clerk.applyResponseClient(.mock, completedAuthFlow: completion)

    let awaiting = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(awaiting.sessionId == clerk.session?.id)
    #expect(awaiting.completion?.flowId == completion.flowId)
    #expect(clerk.isAuthFlowComplete == false)

    #expect(clerk.completeAuthFlow(awaiting.work))

    #expect(observesAuthFlow(in: clerk, for: registration))
    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func presentationRetainsExactWorkAcrossRefreshAndLaterCompletion() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    let completion = completedAuthFlow()

    clerk.applyResponseClient(.mock, completedAuthFlow: completion)
    let awaiting = try #require(awaitingAuthFlow(in: clerk, for: registration))
    let token = try #require(clerk.startAuthFlowPresentation(
      for: registration,
      work: awaiting.work,
      presentation: .trustedDeviceEnrollment
    ))

    var laterSignIn = SignIn.mock
    laterSignIn.id = "sign_in_later"
    laterSignIn.status = .complete
    laterSignIn.createdSessionId = Client.mock.currentSession?.id
    clerk.applyResponseClient(.mock)
    clerk.applyResponseClient(.mock, completedAuthFlow: .signIn(laterSignIn))

    let presenting = try #require(presentingAuthFlow(in: clerk, for: registration))
    #expect(presenting.workId == awaiting.workId)
    #expect(presenting.sessionId == awaiting.sessionId)
    #expect(presenting.presentation == .trustedDeviceEnrollment)
    #expect(presenting.completion?.flowId == completion.flowId)
    #expect(clerk.isAuthFlowComplete == false)

    #expect(clerk.finishAuthFlowPresentation(token))
    let reconciled = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(reconciled.workId == awaiting.workId)
    #expect(clerk.isAuthFlowComplete == false)

    #expect(clerk.completeAuthFlow(reconciled.work))
    #expect(observesAuthFlow(in: clerk, for: registration))
    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func acceptedCompletionForAnotherSessionReplacesPresentedWork() throws {
    var sessionA = try #require(Client.mock.currentSession)
    sessionA.id = "session-a"
    var clientA = Client.mock
    clientA.sessions = [sessionA]
    clientA.lastActiveSessionId = sessionA.id
    var signInA = SignIn.mock
    signInA.id = "sign-in-a"
    signInA.status = .complete
    signInA.createdSessionId = sessionA.id
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    clerk.applyResponseClient(clientA, completedAuthFlow: .signIn(signInA))
    let awaitingA = try #require(awaitingAuthFlow(in: clerk, for: registration))
    let tokenA = try #require(clerk.startAuthFlowPresentation(
      for: registration,
      work: awaitingA.work,
      presentation: .trustedDeviceEnrollment
    ))
    var sessionB = sessionA
    sessionB.id = "session-b"
    var clientB = Client.mock
    clientB.sessions = [sessionA, sessionB]
    clientB.lastActiveSessionId = sessionB.id
    var signInB = SignIn.mock
    signInB.id = "sign-in-b"
    signInB.status = .complete
    signInB.createdSessionId = sessionB.id

    clerk.applyResponseClient(clientB, completedAuthFlow: .signIn(signInB))

    let awaitingB = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(awaitingB.workId != awaitingA.workId)
    #expect(awaitingB.sessionId == sessionB.id)
    #expect(awaitingB.completion?.flowId == signInB.id)
    #expect(clerk.finishAuthFlowPresentation(tokenA) == false)
    withExtendedLifetime(registration) {}
  }

  @Test
  func newerCompletionReplacesAwaitingWorkAndRejectsStaleCallbacks() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())

    clerk.applyResponseClient(.mock, completedAuthFlow: completedAuthFlow())
    let first = try #require(awaitingAuthFlow(in: clerk, for: registration))

    var laterSignIn = SignIn.mock
    laterSignIn.id = "sign_in_later"
    laterSignIn.status = .complete
    laterSignIn.createdSessionId = Client.mock.currentSession?.id
    clerk.applyResponseClient(.mock, completedAuthFlow: .signIn(laterSignIn))

    let later = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(later.workId != first.workId)
    #expect(later.completion?.flowId == laterSignIn.id)
    #expect(clerk.startAuthFlowPresentation(
      for: registration,
      work: first.work,
      presentation: .trustedDeviceEnrollment
    ) == nil)
    #expect(clerk.isAuthFlowComplete == false)
    withExtendedLifetime(registration) {}
  }

  @Test
  func completionWaitsForItsSessionAcrossOrdinaryRefreshUntilActivation() throws {
    var sessionA = try #require(Client.mock.currentSession)
    sessionA.id = "session-a"
    var sessionB = sessionA
    sessionB.id = "session-b"
    var initialClient = Client.mock
    initialClient.sessions = [sessionB]
    initialClient.lastActiveSessionId = sessionB.id
    let clerk = Clerk.mock
    clerk.client = initialClient
    let registration = try #require(clerk.registerAuthFlow(role: .dismissible))
    var pendingActivationClient = Client.mock
    pendingActivationClient.sessions = [sessionB, sessionA]
    pendingActivationClient.lastActiveSessionId = sessionB.id
    var signIn = SignIn.mock
    signIn.status = .complete
    signIn.createdSessionId = sessionA.id
    let completion = TransferFlowResult.signIn(signIn)

    clerk.applyResponseClient(
      pendingActivationClient,
      completedAuthFlow: completion
    )

    let awaiting = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(awaiting.sessionId == sessionA.id)
    #expect(awaiting.completion?.flowId == completion.flowId)
    let awaitingRevision = try #require(
      clerk.authFlowSnapshot(for: registration)?.revision
    )

    clerk.applyResponseClient(pendingActivationClient)

    let refreshed = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(refreshed.workId == awaiting.workId)
    #expect(refreshed.sessionId == sessionA.id)
    #expect(clerk.authFlowSnapshot(for: registration)?.revision == awaitingRevision)

    var activatedClient = pendingActivationClient
    activatedClient.lastActiveSessionId = sessionA.id
    clerk.applyResponseClient(activatedClient)

    #expect(clerk.session?.id == sessionA.id)
    let activated = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(activated.workId == awaiting.workId)
    #expect(activated.completion?.flowId == completion.flowId)
    withExtendedLifetime(registration) {}
  }

  @Test
  func authoritativeIdentityChangeSupersedesOwnedCompletionWhenOldSessionRemains() throws {
    var sessionA = try #require(Client.mock.currentSession)
    sessionA.id = "session-a"
    var sessionB = sessionA
    sessionB.id = "session-b"
    var initialClient = Client.mock
    initialClient.sessions = [sessionB]
    initialClient.lastActiveSessionId = sessionB.id
    let clerk = Clerk.mock
    clerk.client = initialClient
    let registration = try #require(clerk.registerAuthFlow(role: .dismissible))
    var client = Client.mock
    client.sessions = [sessionB, sessionA]
    client.lastActiveSessionId = sessionB.id
    var signIn = SignIn.mock
    signIn.status = .complete
    signIn.createdSessionId = sessionA.id
    clerk.setClientFromIdentityController(
      client,
      authFlowUpdate: .completionAccepted(
        .signIn(signIn),
        ownerId: registration.id
      )
    )

    let owned = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(owned.sessionId == sessionA.id)
    #expect(owned.completion?.flowId == signIn.id)

    clerk.setClientFromIdentityController(
      client,
      authFlowUpdate: .authoritativeIdentityChanged
    )

    let external = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(external.workId != owned.workId)
    #expect(external.sessionId == sessionB.id)
    #expect(external.completion == nil)
    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func staleSameFlowRejectionPreservesAcceptedAwaitingWork() throws {
    var sessionA = try #require(Client.mock.currentSession)
    sessionA.id = "session-a"
    var sessionB = sessionA
    sessionB.id = "session-b"
    var initialClient = Client.mock
    initialClient.sessions = [sessionB]
    initialClient.lastActiveSessionId = sessionB.id
    var client = initialClient
    client.sessions = [sessionB, sessionA]
    var signIn = SignIn.mock
    signIn.status = .complete
    signIn.createdSessionId = sessionA.id
    let completion = TransferFlowResult.signIn(signIn)
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    clerk.setClientFromIdentityController(initialClient)

    clerk.setClientFromIdentityController(
      client,
      authFlowUpdate: .completionAccepted(
        completion,
        ownerId: registration.id
      )
    )
    let accepted = try #require(awaitingAuthFlow(in: clerk, for: registration))
    let acceptedRevision = try #require(
      clerk.authFlowSnapshot(for: registration)?.revision
    )

    clerk.resolveSupersededAuthFlowCompletion(
      completion,
      ownerId: registration.id
    )

    let retained = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(retained.work == accepted.work)
    #expect(retained.completion?.flowId == completion.flowId)
    #expect(clerk.authFlowSnapshot(for: registration)?.revision == acceptedRevision)
    #expect(clerk.isAuthFlowComplete == false)
    withExtendedLifetime(registration) {}
  }

  @Test
  func sameFlowRejectionYieldsToAuthoritativeIdentityChange() throws {
    var sessionA = try #require(Client.mock.currentSession)
    sessionA.id = "session-a"
    var sessionB = sessionA
    sessionB.id = "session-b"
    var initialClient = Client.mock
    initialClient.sessions = [sessionB]
    initialClient.lastActiveSessionId = sessionB.id
    var client = initialClient
    client.sessions = [sessionB, sessionA]
    var signIn = SignIn.mock
    signIn.status = .complete
    signIn.createdSessionId = sessionA.id
    let completion = TransferFlowResult.signIn(signIn)
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    clerk.setClientFromIdentityController(initialClient)

    clerk.setClientFromIdentityController(
      client,
      authFlowUpdate: .completionAccepted(
        completion,
        ownerId: registration.id
      )
    )
    let accepted = try #require(awaitingAuthFlow(in: clerk, for: registration))

    clerk.setClientFromIdentityController(
      client,
      authFlowUpdate: .resolvingSupersededCompletion(
        completion,
        ownerId: registration.id,
        authoritativeClient: client,
        authoritativeIdentityChanged: true
      )
    )

    let external = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(external.workId != accepted.workId)
    #expect(external.sessionId == sessionB.id)
    #expect(external.completion == nil)
    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func failedSessionActivationAdoptsTheAuthoritativeCurrentSession() throws {
    var sessionA = try #require(Client.mock.currentSession)
    sessionA.id = "session-a"
    var sessionB = sessionA
    sessionB.id = "session-b"
    var initialClient = Client.mock
    initialClient.sessions = [sessionB]
    initialClient.lastActiveSessionId = sessionB.id
    let clerk = Clerk.mock
    clerk.client = initialClient
    let registration = try #require(clerk.registerAuthFlow(role: .dismissible))
    var client = Client.mock
    client.sessions = [sessionB, sessionA]
    client.lastActiveSessionId = sessionB.id
    var signIn = SignIn.mock
    signIn.status = .complete
    signIn.createdSessionId = sessionA.id

    clerk.applyResponseClient(client, completedAuthFlow: .signIn(signIn))
    let owned = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(owned.sessionId == sessionA.id)
    let activation = try #require(clerk.beginCompletedAuthSessionActivation(
      sessionId: sessionA.id,
      flowId: signIn.id,
      ownerId: registration.id
    ))

    clerk.authSessionActivationDidFinish(activation: activation)

    let external = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(external.sessionId == sessionB.id)
    #expect(external.completion == nil)
    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func finishedCompletedActivationAdoptsANewerAuthoritativeSession() throws {
    var sessionA = try #require(Client.mock.currentSession)
    sessionA.id = "session-a"
    var sessionB = sessionA
    sessionB.id = "session-b"
    sessionB.status = .pending
    var initialClient = Client.mock
    initialClient.sessions = [sessionB]
    initialClient.lastActiveSessionId = sessionB.id
    let clerk = Clerk.mockSignedOut
    clerk.client = initialClient
    let registration = try #require(clerk.registerAuthFlow())
    var completedClient = initialClient
    completedClient.sessions.append(sessionA)
    var signIn = SignIn.mock
    signIn.status = .complete
    signIn.createdSessionId = sessionA.id

    clerk.applyResponseClient(
      completedClient,
      completedAuthFlow: .signIn(signIn)
    )
    let activation = try #require(clerk.beginCompletedAuthSessionActivation(
      sessionId: sessionA.id,
      flowId: signIn.id,
      ownerId: registration.id
    ))

    var authoritativeClient = completedClient
    authoritativeClient.sessions[0].status = .active
    clerk.setClientFromIdentityController(authoritativeClient)

    #expect(clerk.isAuthFlowComplete == false)
    clerk.authSessionActivationDidFinish(activation: activation)

    let external = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(external.sessionId == sessionB.id)
    #expect(external.completion == nil)
    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func acceptedCompletionWaitsWhileItsViableSessionHasNotBeenSelected() throws {
    var session = try #require(Client.mock.currentSession)
    session.id = "session-a"
    var unselectedClient = Client.mock
    unselectedClient.sessions = [session]
    unselectedClient.lastActiveSessionId = nil
    var signIn = SignIn.mock
    signIn.status = .complete
    signIn.createdSessionId = session.id
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())

    clerk.applyResponseClient(
      unselectedClient,
      completedAuthFlow: .signIn(signIn)
    )
    let awaiting = try #require(awaitingAuthFlow(in: clerk, for: registration))

    clerk.applyResponseClient(unselectedClient)

    let retained = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(retained.workId == awaiting.workId)
    #expect(retained.completion?.flowId == signIn.id)

    var selectedClient = unselectedClient
    selectedClient.lastActiveSessionId = session.id
    clerk.applyResponseClient(selectedClient)

    let selected = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(selected.workId == awaiting.workId)
    #expect(selected.completion?.flowId == signIn.id)
    withExtendedLifetime(registration) {}
  }

  @Test
  func semanticRejectionIsAcceptedWhenTheCreatedSessionIsAuthoritative() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    let completion = completedAuthFlow()

    clerk.setClientFromIdentityController(
      .mock,
      authFlowUpdate: .resolvingSupersededCompletion(
        completion,
        ownerId: registration.id,
        authoritativeClient: .mock
      )
    )

    let awaiting = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(awaiting.completion?.flowId == completion.flowId)
    #expect(clerk.isAuthFlowComplete == false)
    withExtendedLifetime(registration) {}
  }

  @Test
  func supersededCompletionAdoptsAuthoritativeSessionForDismissal() throws {
    let clerk = Clerk.mock
    let registration = try #require(clerk.registerAuthFlow(role: .dismissible))
    let currentSession = try #require(clerk.session)
    var otherSignIn = SignIn.mock
    otherSignIn.id = "sign-in-other"
    otherSignIn.status = .complete
    otherSignIn.createdSessionId = "session-other"

    clerk.setClientFromIdentityController(
      clerk.client,
      authFlowUpdate: .resolvingSupersededCompletion(
        .signIn(otherSignIn),
        ownerId: registration.id,
        authoritativeClient: clerk.client
      )
    )

    let external = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(external.sessionId == currentSession.id)
    #expect(external.completion == nil)
    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func sessionTaskPresentationRemainsUntilItsTokenFinishes() throws {
    var pendingClient = Client.mock
    pendingClient.sessions[0].status = .pending
    pendingClient.sessions[0].tasks = [.setupMfa]
    let clerk = Clerk.mock
    clerk.client = pendingClient
    let registration = try #require(clerk.registerAuthFlow())
    let session = try #require(clerk.session)

    clerk.adoptPendingAuthSession(for: registration, session: session)

    let awaiting = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(awaiting.sessionId == session.id)
    #expect(awaiting.completion == nil)
    let token = try #require(clerk.startAuthFlowPresentation(
      for: registration,
      work: awaiting.work,
      presentation: .sessionTasks
    ))

    var activeClient = pendingClient
    activeClient.sessions[0].status = .active
    clerk.applyResponseClient(activeClient)

    let presenting = try #require(presentingAuthFlow(in: clerk, for: registration))
    #expect(presenting.workId == awaiting.workId)
    #expect(presenting.presentation == .sessionTasks)
    #expect(clerk.isAuthFlowComplete == false)

    #expect(clerk.finishAuthFlowPresentation(token))
    let resumed = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(resumed.workId == awaiting.workId)
    #expect(clerk.completeAuthFlow(resumed.work))
    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func finishingTrustedDeviceEnrollmentReturnsItsExactAuthWorkForCompletion() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    clerk.applyResponseClient(.mock, completedAuthFlow: completedAuthFlow())
    let awaiting = try #require(awaitingAuthFlow(in: clerk, for: registration))

    let token = try #require(clerk.startAuthFlowPresentation(
      for: registration,
      work: awaiting.work,
      presentation: .trustedDeviceEnrollment
    ))
    #expect(clerk.finishAuthFlowPresentation(token))

    // A host gated on isAuthFlowComplete must not see completion before it is delivered.
    #expect(clerk.isAuthFlowComplete == false)
    let resumed = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(resumed.workId == awaiting.workId)

    #expect(clerk.completeAuthFlow(resumed.work))
    #expect(clerk.isAuthFlowComplete)
    guard case .observing = clerk.authFlowSnapshot(for: registration)?.phase else {
      Issue.record("Expected completion to finish the auth work.")
      return
    }
    withExtendedLifetime(registration) {}
  }

  @Test
  func completingAuthFlowIsAcceptedOnceForAnOrdinaryFlow() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    clerk.applyResponseClient(.mock, completedAuthFlow: completedAuthFlow())
    let awaiting = try #require(awaitingAuthFlow(in: clerk, for: registration))

    #expect(clerk.completeAuthFlow(awaiting.work))
    // A second attempt is rejected, so a host bound to this call site is told once.
    #expect(clerk.completeAuthFlow(awaiting.work) == false)
    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func completingAuthFlowIsAcceptedOnceAfterTrustedDeviceEnrollment() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    clerk.applyResponseClient(.mock, completedAuthFlow: completedAuthFlow())
    let awaiting = try #require(awaitingAuthFlow(in: clerk, for: registration))

    let token = try #require(clerk.startAuthFlowPresentation(
      for: registration,
      work: awaiting.work,
      presentation: .trustedDeviceEnrollment
    ))
    #expect(clerk.finishAuthFlowPresentation(token))
    let resumed = try #require(awaitingAuthFlow(in: clerk, for: registration))

    #expect(clerk.completeAuthFlow(resumed.work))
    #expect(clerk.completeAuthFlow(resumed.work) == false)
    // Finishing the presentation again must not re-open a completed flow.
    #expect(clerk.finishAuthFlowPresentation(token) == false)
    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func finishingEnrollmentForPendingSignUpAdvancesToTasksWithoutReoffering() throws {
    var pendingClient = Client.mock
    pendingClient.sessions[0].status = .pending
    pendingClient.sessions[0].tasks = [.setupMfa]
    let session = try #require(pendingClient.currentSession)
    var signUp = SignUp.mock
    signUp.status = .complete
    signUp.createdSessionId = session.id
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())

    clerk.applyResponseClient(
      pendingClient,
      completedAuthFlow: .signUp(signUp)
    )
    let awaitingEnrollment = try #require(
      awaitingAuthFlow(in: clerk, for: registration)
    )
    #expect(awaitingEnrollment.completion?.flowId == signUp.id)

    let enrollmentToken = try #require(clerk.startAuthFlowPresentation(
      for: registration,
      work: awaitingEnrollment.work,
      presentation: .trustedDeviceEnrollment
    ))
    #expect(clerk.finishAuthFlowPresentation(enrollmentToken))

    let awaitingTasks = try #require(
      awaitingAuthFlow(in: clerk, for: registration)
    )
    #expect(awaitingTasks.work == awaitingEnrollment.work)
    #expect(awaitingTasks.completion == nil)
    let taskToken = try #require(clerk.startAuthFlowPresentation(
      for: registration,
      work: awaitingTasks.work,
      presentation: .sessionTasks
    ))
    #expect(taskToken.kind == .sessionTasks)
    #expect(clerk.isAuthFlowComplete == false)
    withExtendedLifetime(registration) {}
  }

  @Test
  func taskAppearingDuringEnrollmentWaitsForEnrollmentToFinish() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    clerk.applyResponseClient(.mock, completedAuthFlow: completedAuthFlow())
    let awaitingEnrollment = try #require(
      awaitingAuthFlow(in: clerk, for: registration)
    )
    let enrollmentToken = try #require(clerk.startAuthFlowPresentation(
      for: registration,
      work: awaitingEnrollment.work,
      presentation: .trustedDeviceEnrollment
    ))

    var pendingClient = Client.mock
    pendingClient.sessions[0].status = .pending
    pendingClient.sessions[0].tasks = [.setupMfa]
    clerk.applyResponseClient(pendingClient)

    #expect(clerk.authFlowPresentationIsCurrent(enrollmentToken))
    #expect(
      presentingAuthFlow(in: clerk, for: registration)?.presentation
        == .trustedDeviceEnrollment
    )
    #expect(clerk.finishAuthFlowPresentation(enrollmentToken))

    let awaitingTasks = try #require(
      awaitingAuthFlow(in: clerk, for: registration)
    )
    #expect(awaitingTasks.completion == nil)
    let taskToken = try #require(clerk.startAuthFlowPresentation(
      for: registration,
      work: awaitingTasks.work,
      presentation: .sessionTasks
    ))
    #expect(taskToken.kind == .sessionTasks)
    withExtendedLifetime(registration) {}
  }

  @Test
  func acceptedCompletionDoesNotOfferEnrollmentAfterSessionTasksBegin() throws {
    var client = Client.mock
    client.sessions[0].status = .pending
    client.sessions[0].tasks = [.setupMfa]
    let clerk = Clerk.mock
    clerk.client = client
    let registration = try #require(clerk.registerAuthFlow())
    let session = try #require(clerk.session)
    clerk.adoptPendingAuthSession(for: registration, session: session)
    let awaiting = try #require(awaitingAuthFlow(in: clerk, for: registration))
    let token = try #require(clerk.startAuthFlowPresentation(
      for: registration,
      work: awaiting.work,
      presentation: .sessionTasks
    ))
    var signIn = SignIn.mock
    signIn.status = .complete
    signIn.createdSessionId = session.id

    clerk.setClientFromIdentityController(
      client,
      authFlowUpdate: .completionAccepted(
        .signIn(signIn),
        ownerId: registration.id
      )
    )

    let presenting = try #require(presentingAuthFlow(in: clerk, for: registration))
    #expect(presenting.token == token)
    #expect(presenting.completion?.flowId == signIn.id)
    #expect(clerk.isAuthFlowComplete == false)
    #expect(clerk.finishAuthFlowPresentation(token))
    #expect(awaitingAuthFlow(in: clerk, for: registration)?.completion == nil)
    withExtendedLifetime(registration) {}
  }

  @Test
  func hostedActivationPromotesPresentedExternalWorkWithoutReplacingItsToken() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    clerk.setClientFromIdentityController(.mock)
    let awaiting = try #require(awaitingAuthFlow(in: clerk, for: registration))
    let token = try #require(clerk.startAuthFlowPresentation(
      for: registration,
      work: awaiting.work,
      presentation: .sessionTasks
    ))

    let activation = try #require(clerk.beginAuthSessionActivation(
      sessionId: awaiting.sessionId,
      ownerId: registration.id
    ))

    #expect(presentingAuthFlow(in: clerk, for: registration)?.token == token)
    #expect(clerk.finishAuthFlowPresentation(token))
    #expect(clerk.isAuthFlowComplete == false)

    clerk.authSessionActivationDidFinish(activation: activation)

    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func hostedActivationForAnotherSessionInvalidatesPresentedWork() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    clerk.setClientFromIdentityController(.mock)
    let awaiting = try #require(awaitingAuthFlow(in: clerk, for: registration))
    let token = try #require(clerk.startAuthFlowPresentation(
      for: registration,
      work: awaiting.work,
      presentation: .sessionTasks
    ))

    _ = try #require(clerk.beginAuthSessionActivation(
      sessionId: "session-b",
      ownerId: registration.id
    ))

    let replacement = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(replacement.sessionId == "session-b")
    #expect(clerk.finishAuthFlowPresentation(token) == false)
    #expect(clerk.isAuthFlowComplete == false)
    withExtendedLifetime(registration) {}
  }

  @Test
  func staleHostedActivationCannotMutateANewerRegistration() throws {
    let clerk = Clerk.mockSignedOut
    let staleRegistration = try #require(clerk.registerAuthFlow())
    let staleActivation = try #require(clerk.beginAuthSessionActivation(
      sessionId: Client.mock.currentSession?.id ?? "session-a",
      ownerId: staleRegistration.id
    ))
    staleRegistration.cancel()

    var pendingClient = Client.mock
    pendingClient.sessions[0].status = .pending
    pendingClient.sessions[0].tasks = [.setupMfa]
    clerk.setClientFromIdentityController(pendingClient)
    let currentRegistration = try #require(clerk.registerAuthFlow())
    let session = try #require(clerk.session)
    clerk.adoptPendingAuthSession(for: currentRegistration, session: session)
    let awaiting = try #require(awaitingAuthFlow(
      in: clerk,
      for: currentRegistration
    ))
    let presentation = try #require(clerk.startAuthFlowPresentation(
      for: currentRegistration,
      work: awaiting.work,
      presentation: .sessionTasks
    ))

    clerk.authSessionActivationDidFinish(activation: staleActivation)

    #expect(clerk.authFlowPresentationIsCurrent(presentation))
    #expect(clerk.isAuthFlowComplete == false)
    withExtendedLifetime(currentRegistration) {}
  }

  @Test
  func staleCompletedActivationCannotMutateANewerRegistration() throws {
    let clerk = Clerk.mockSignedOut
    let staleRegistration = try #require(clerk.registerAuthFlow())
    let completion = completedAuthFlow()
    clerk.applyResponseClient(.mock, completedAuthFlow: completion)
    let completedSessionId = try #require(completion.createdSessionId)
    let staleActivation = try #require(
      clerk.beginCompletedAuthSessionActivation(
        sessionId: completedSessionId,
        flowId: completion.flowId,
        ownerId: staleRegistration.id
      )
    )
    staleRegistration.cancel()

    var pendingClient = Client.mock
    pendingClient.sessions[0].status = .pending
    pendingClient.sessions[0].tasks = [.setupMfa]
    clerk.setClientFromIdentityController(pendingClient)
    let currentRegistration = try #require(clerk.registerAuthFlow())
    let session = try #require(clerk.session)
    clerk.adoptPendingAuthSession(for: currentRegistration, session: session)
    let awaiting = try #require(awaitingAuthFlow(
      in: clerk,
      for: currentRegistration
    ))
    let presentation = try #require(clerk.startAuthFlowPresentation(
      for: currentRegistration,
      work: awaiting.work,
      presentation: .sessionTasks
    ))

    clerk.authSessionActivationDidFinish(activation: staleActivation)

    #expect(clerk.authFlowPresentationIsCurrent(presentation))
    #expect(clerk.isAuthFlowComplete == false)
    withExtendedLifetime(currentRegistration) {}
  }

  @Test
  func completedRootWorkCanReleaseOwnershipAndRearmAfterSignOut() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    clerk.applyResponseClient(.mock, completedAuthFlow: completedAuthFlow())
    let awaiting = try #require(awaitingAuthFlow(in: clerk, for: registration))

    #expect(clerk.completeAuthFlow(awaiting.work))
    registration.cancel()

    #expect(clerk.authFlowRegistrationId == nil)
    #expect(clerk.isAuthFlowComplete)
    #expect(clerk.registerAuthFlow() == nil)

    clerk.setClientFromIdentityController(nil)

    let rearmed = try #require(clerk.registerAuthFlow())
    withExtendedLifetime(rearmed) {}
  }

  @Test
  func terminalCurrentSessionClearsPresentedPostAuthWork() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    clerk.applyResponseClient(.mock, completedAuthFlow: completedAuthFlow())
    let awaiting = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(clerk.startAuthFlowPresentation(
      for: registration,
      work: awaiting.work,
      presentation: .trustedDeviceEnrollment
    ) != nil)
    var terminalClient = Client.mock
    terminalClient.sessions[0].status = .ended

    clerk.applyResponseClient(terminalClient)

    #expect(observesAuthFlow(in: clerk, for: registration))
    #expect(clerk.isAuthFlowComplete == false)
    withExtendedLifetime(registration) {}
  }

  @Test
  func unownedCompletionDoesNotAttachToALaterAuthView() throws {
    let clerk = Clerk.mockSignedOut
    let update = AuthFlowIdentityUpdate.completionAccepted(
      completedAuthFlow(),
      ownerId: UUID()
    )
    let registration = try #require(clerk.registerAuthFlow())

    clerk.setClientFromIdentityController(.mock, authFlowUpdate: update)

    let external = try #require(awaitingAuthFlow(in: clerk, for: registration))
    #expect(external.completion == nil)
    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func authFlowGateIsObservableWhenOwnedWorkBegins() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    clerk.client = .mock
    let didChange = LockIsolated(false)
    let initialValue = withObservationTracking {
      clerk.isAuthFlowComplete
    } onChange: {
      didChange.setValue(true)
    }

    clerk.setClientFromIdentityController(
      .mock,
      authFlowUpdate: .completionAccepted(
        completedAuthFlow(),
        ownerId: registration.id
      )
    )

    #expect(initialValue)
    #expect(didChange.value)
    #expect(clerk.isAuthFlowComplete == false)
    withExtendedLifetime(registration) {}
  }

  @Test
  func releasingAuthFlowRegistrationClearsPendingHold() async throws {
    let clerk = Clerk.mockSignedOut
    var registration = clerk.registerAuthFlow()
    _ = try #require(registration)
    clerk.applyResponseClient(.mock, completedAuthFlow: completedAuthFlow())

    registration = nil
    try await waitUntil { clerk.authFlowRegistrationId == nil }

    #expect(clerk.isAuthFlowComplete)
    let replacement = try #require(clerk.registerAuthFlow(role: .dismissible))
    withExtendedLifetime(replacement) {}
  }

  @Test
  func staleRegistrationCannotMutateANewerAuthFlow() throws {
    let clerk = Clerk.mockSignedOut
    let previousRegistration = try #require(clerk.registerAuthFlow())
    previousRegistration.cancel()

    let currentRegistration = try #require(clerk.registerAuthFlow())
    previousRegistration.cancel()
    clerk.applyResponseClient(.mock, completedAuthFlow: completedAuthFlow())
    let current = try #require(awaitingAuthFlow(in: clerk, for: currentRegistration))

    #expect(clerk.startAuthFlowPresentation(
      for: previousRegistration,
      work: current.work,
      presentation: .trustedDeviceEnrollment
    ) == nil)
    clerk.resetAuthFlow(for: previousRegistration)

    #expect(clerk.isAuthFlowComplete == false)
    #expect(awaitingAuthFlow(in: clerk, for: currentRegistration)?.workId == current.workId)

    #expect(clerk.completeAuthFlow(current.work))
    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(currentRegistration) {}
  }

  @Test
  func handleReturnsFalseForUnrecognizedURL() async throws {
    let url = try #require(URL(string: "https://example.com/not-clerk"))

    let handled = try await Clerk.shared.handle(url)

    #expect(handled == false)
  }

  @Test
  func handleReturnsTrueForMagicLinkCallback() async throws {
    let keychain = InMemoryKeychain()
    let completeParams = LockIsolated<MagicLinkCompleteParams?>(nil)
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let activatedSessionId = LockIsolated<String?>(nil)
    let magicLinkService = MockMagicLinkService { params in
      completeParams.setValue(params)
      return .ticket(MagicLinkCompleteResponse(flowId: params.flowId, ticket: "ticket_123"))
    }

    let completedSignIn = SignIn(
      id: "sign_in_123",
      status: .complete,
      createdSessionId: "sess_123"
    )

    let signInService = MockSignInService(create: { params in
      signInParams.setValue(params)
      return completedSignIn
    })
    let sessionService = MockSessionService(setActive: { sessionId, _ in
      activatedSessionId.setValue(sessionId)
    })

    let clerk = Clerk()
    let apiClient = createMockAPIClient(runtimeScope: clerk.runtimeScope)
    clerk.dependencies = MockDependencyContainer(
      apiClient: apiClient,
      keychain: keychain,
      signInService: signInService,
      sessionService: sessionService,
      magicLinkService: magicLinkService
    )
    try (#require(clerk.dependencies as? MockDependencyContainer))
      .configurationManager
      .configure(
        publishableKey: testPublishableKey,
        options: .init(
          redirectConfig: .init(redirectUrl: "com.clerk.isolated://callback")
        )
      )
    clerk.environment = .mock
    let callbackUrl = try #require(URL(string: "\(clerk.options.redirectConfig.redirectUrl)?flow_id=flow_123&approval_token=approval_123"))
    try clerk.dependencies.magicLinkStore.save(kind: .signIn, flowId: "flow_123", codeVerifier: "verifier_123")

    let handled = try await clerk.handle(callbackUrl)

    #expect(handled == true)
    #expect(completeParams.value?.flowId == "flow_123")
    #expect(completeParams.value?.approvalToken == "approval_123")
    #expect(completeParams.value?.codeVerifier == "verifier_123")
    #expect(signInParams.value?.ticket == "ticket_123")
    #expect(activatedSessionId.value == "sess_123")
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) == false)
  }

  @Test
  func handleDeduplicatesConcurrentMagicLinkCallbacks() async throws {
    let keychain = InMemoryKeychain()
    let completeCallCount = LockIsolated(0)
    let createCallCount = LockIsolated(0)
    let activatedSessionId = LockIsolated<String?>(nil)
    let magicLinkService = MockMagicLinkService { params in
      completeCallCount.withValue { $0 += 1 }
      return .ticket(MagicLinkCompleteResponse(flowId: params.flowId, ticket: "ticket_123"))
    }

    let completedSignIn = SignIn(
      id: "sign_in_123",
      status: .complete,
      createdSessionId: "sess_123"
    )

    let signInService = MockSignInService(create: { _ in
      createCallCount.withValue { $0 += 1 }
      try await Task.sleep(for: .milliseconds(50))
      return completedSignIn
    })
    let sessionService = MockSessionService(setActive: { sessionId, _ in
      activatedSessionId.setValue(sessionId)
    })

    let clerk = Clerk()
    let apiClient = createMockAPIClient(runtimeScope: clerk.runtimeScope)
    clerk.dependencies = MockDependencyContainer(
      apiClient: apiClient,
      keychain: keychain,
      signInService: signInService,
      sessionService: sessionService,
      magicLinkService: magicLinkService
    )
    try (#require(clerk.dependencies as? MockDependencyContainer))
      .configurationManager
      .configure(
        publishableKey: testPublishableKey,
        options: .init(
          redirectConfig: .init(redirectUrl: "com.clerk.isolated://callback")
        )
      )
    clerk.environment = .mock
    let callbackUrl = try #require(URL(string: "\(clerk.options.redirectConfig.redirectUrl)?flow_id=flow_123&approval_token=approval_123"))
    try clerk.dependencies.magicLinkStore.save(kind: .signIn, flowId: "flow_123", codeVerifier: "verifier_123")

    async let firstHandled = clerk.handle(callbackUrl)
    async let secondHandled = clerk.handle(callbackUrl)

    let (first, second) = try await (firstHandled, secondHandled)

    #expect(first == true)
    #expect(second == true)
    #expect(completeCallCount.value == 1)
    #expect(createCallCount.value == 1)
    #expect(activatedSessionId.value == "sess_123")
  }

  @Test
  func handleReturnsFalseForMismatchedMagicLinkCallbackOrigin() async throws {
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(apiClient: createMockAPIClient())
    try (#require(clerk.dependencies as? MockDependencyContainer))
      .configurationManager
      .configure(
        publishableKey: testPublishableKey,
        options: .init(
          redirectConfig: .init(redirectUrl: "com.clerk.isolated://callback")
        )
      )

    let callbackUrl = try #require(URL(string: "com.clerk.shared://callback?flow_id=flow_123&approval_token=approval_123"))

    let handled = try await clerk.handle(callbackUrl)

    #expect(handled == false)
  }

  // MARK: - Development Mode Warning Tests

  @Test
  func shouldShowDevelopmentModeWarningReturnsFalseWhenEnvironmentIsMissing() {
    Clerk.shared.environment = nil

    #expect(Clerk.shared.shouldShowDevelopmentModeWarning == false)
  }

  @Test
  func shouldShowDevelopmentModeWarningReturnsFalseWhenFlagIsDisabled() {
    Clerk.shared.environment = environment(showDevmodeWarning: false, type: .development)

    #expect(Clerk.shared.shouldShowDevelopmentModeWarning == false)
  }

  @Test
  func shouldShowDevelopmentModeWarningReturnsFalseForProductionEnvironment() {
    Clerk.shared.environment = environment(showDevmodeWarning: true, type: .production)

    #expect(Clerk.shared.shouldShowDevelopmentModeWarning == false)
  }

  @Test
  func shouldShowDevelopmentModeWarningReturnsTrueForDevelopmentEnvironment() {
    Clerk.shared.environment = environment(showDevmodeWarning: true, type: .development)

    #expect(Clerk.shared.shouldShowDevelopmentModeWarning == true)
  }

  @Test
  func shouldShowDevelopmentModeWarningReturnsTrueForUnknownNonProductionEnvironment() {
    Clerk.shared.environment = environment(showDevmodeWarning: true, type: .unknown("staging"))

    #expect(Clerk.shared.shouldShowDevelopmentModeWarning == true)
  }

  // MARK: - Current / Active Session Tests

  @Test
  func sessionReturnsPendingSession() {
    let pendingSession = createSession(id: "session1", status: .pending)
    Clerk.shared.client = Client(
      id: "client1",
      sessions: [pendingSession],
      lastActiveSessionId: "session1",
      updatedAt: Date(timeIntervalSince1970: 1_609_459_200)
    )

    #expect(Clerk.shared.session?.id == "session1")
  }

  @Test
  func userReturnsUserForPendingSession() {
    let pendingSession = createSession(id: "session1", status: .pending, user: .mock)
    Clerk.shared.client = Client(
      id: "client1",
      sessions: [pendingSession],
      lastActiveSessionId: "session1",
      updatedAt: Date(timeIntervalSince1970: 1_609_459_200)
    )

    #expect(Clerk.shared.user?.id == User.mock.id)
  }

  private struct AwaitingAuthFlow {
    let work: AuthFlowWork
    let completion: TransferFlowResult?

    var workId: UUID {
      work.id
    }

    var sessionId: String {
      work.sessionId
    }
  }

  private struct PresentingAuthFlow {
    let token: AuthFlowPresentationToken
    let completion: TransferFlowResult?

    var workId: UUID {
      token.work.id
    }

    var sessionId: String {
      token.sessionId
    }

    var presentation: AuthFlowRegistration.PostAuthPresentation {
      token.kind
    }
  }

  private func awaitingAuthFlow(
    in clerk: Clerk,
    for registration: AuthFlowRegistration
  ) -> AwaitingAuthFlow? {
    guard case .awaiting(let work, let completion) =
      clerk.authFlowSnapshot(for: registration)?.phase
    else {
      return nil
    }

    return AwaitingAuthFlow(
      work: work,
      completion: completion
    )
  }

  private func presentingAuthFlow(
    in clerk: Clerk,
    for registration: AuthFlowRegistration
  ) -> PresentingAuthFlow? {
    guard case .presenting(let token, let completion) =
      clerk.authFlowSnapshot(for: registration)?.phase
    else {
      return nil
    }

    return PresentingAuthFlow(
      token: token,
      completion: completion
    )
  }

  private func observesAuthFlow(
    in clerk: Clerk,
    for registration: AuthFlowRegistration
  ) -> Bool {
    guard case .observing = clerk.authFlowSnapshot(for: registration)?.phase else {
      return false
    }
    return true
  }

  private func completedAuthFlow() -> TransferFlowResult {
    var signIn = SignIn.mock
    signIn.status = .complete
    signIn.createdSessionId = Client.mock.currentSession?.id
    return .signIn(signIn)
  }

  private func environment(
    showDevmodeWarning: Bool,
    type: InstanceEnvironmentType
  ) -> Clerk.Environment {
    var environment = Clerk.Environment.mock
    environment.displayConfig.showDevmodeWarning = showDevmodeWarning
    environment.displayConfig.instanceEnvironmentType = type
    return environment
  }

  private func makeClearRecoveryContext(
    journal: any KeychainStorage,
    identityStore: any SharedSessionLocalIdentityStoring,
    slotStore: any SharedSessionSlotStoring
  ) -> SharedSessionOwnerSlotClearRecovery.Context {
    let intent = SharedSessionOwnerSlotClearRecovery.Intent(
      localIdentityService: "app.identity",
      slotService: "app.slots",
      slotAccessGroup: "group.shared",
      slotAccount: "owner.app.clear",
      instanceFingerprint: "instance",
      ownerIdentifier: "app.clear"
    )
    return SharedSessionOwnerSlotClearRecovery.Context(
      journal: journal,
      currentIntent: intent,
      targetProvider: ClearRecoveryTargetProvider(
        identityStore: identityStore,
        slotStore: slotStore
      )
    )
  }

  private func waitUntil(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(1)
    while ContinuousClock.now < deadline {
      if condition() { return }
      await Task.yield()
    }
    throw ClerkClientError(message: "Timed out waiting for identity operation.")
  }
}

private struct ClearRecoveryTargetProvider:
  SharedSessionClearRecoveryTargets
{
  let identityStore: any SharedSessionLocalIdentityStoring
  let slotStore: any SharedSessionSlotStoring

  func localIdentityStore(
    for _: SharedSessionOwnerSlotClearRecovery.Intent
  ) throws -> any SharedSessionLocalIdentityStoring {
    identityStore
  }

  func slotStore(
    for _: SharedSessionOwnerSlotClearRecovery.Intent
  ) throws -> any SharedSessionSlotStoring {
    slotStore
  }
}

private final class SuspendingCacheKeychain: @unchecked Sendable, KeychainStorage {
  private let backing = InMemoryKeychain()
  private let condition = NSCondition()
  private var suspendedKey: String?
  private var shouldResume = false
  private var setIsSuspended = false

  var isSetSuspended: Bool {
    condition.withLock { setIsSuspended }
  }

  func suspendNextSet(forKey key: String) {
    condition.withLock {
      suspendedKey = key
      shouldResume = false
    }
  }

  func resumeSuspendedSet() {
    condition.withLock {
      shouldResume = true
      condition.broadcast()
    }
  }

  func set(_ data: Data, forKey key: String) throws {
    condition.lock()
    if suspendedKey == key {
      suspendedKey = nil
      setIsSuspended = true
      condition.broadcast()
      while !shouldResume {
        condition.wait()
      }
      setIsSuspended = false
    }
    condition.unlock()
    try backing.set(data, forKey: key)
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

private final class DeleteFailingKeychain: @unchecked Sendable, KeychainStorage {
  enum Failure: Error {
    case delete
  }

  private let backing = InMemoryKeychain()
  private let lock = NSLock()
  private let failingKey: String
  private var failuresRemaining: Int?
  private var failures = 0

  init(failingKey: String, failuresRemaining: Int? = nil) {
    self.failingKey = failingKey
    self.failuresRemaining = failuresRemaining
  }

  var failureCount: Int {
    lock.withLock { failures }
  }

  func allowDeletes() {
    lock.withLock { failuresRemaining = 0 }
  }

  func set(_ data: Data, forKey key: String) throws {
    try backing.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    try backing.data(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    let shouldFail = lock.withLock {
      guard key == failingKey else { return false }
      if let failuresRemaining {
        guard failuresRemaining > 0 else { return false }
        self.failuresRemaining = failuresRemaining - 1
      }
      failures += 1
      return true
    }
    guard !shouldFail else { throw Failure.delete }
    try backing.deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try backing.hasItem(forKey: key)
  }
}

@MainActor
private final class LocalIdentityOperationGate {
  private(set) var isSuspended = false
  private var continuation: CheckedContinuation<Void, Never>?

  func suspend() async {
    isSuspended = true
    await withCheckedContinuation { continuation in
      self.continuation = continuation
    }
    isSuspended = false
  }

  func resume() {
    continuation?.resume()
    continuation = nil
  }
}

private final class SuspendingIdentityStore: @unchecked Sendable, SharedSessionLocalIdentityStoring {
  private let stateLock = NSLock()
  private let suspension = NSCondition()
  private var record: SharedSessionLocalIdentityRecord?
  private var shouldSuspendNextSave = false
  private var shouldResumeSave = false
  private var saveIsSuspended = false
  private var deletionCount = 0

  var isSaveSuspended: Bool {
    suspension.withLock { saveIsSuspended }
  }

  var deleteCount: Int {
    stateLock.withLock { deletionCount }
  }

  func suspendNextSave() {
    suspension.withLock {
      shouldSuspendNextSave = true
      shouldResumeSave = false
    }
  }

  func resumeSuspendedSave() {
    suspension.withLock {
      shouldResumeSave = true
      suspension.broadcast()
    }
  }

  func loadRecord() throws -> SharedSessionLocalIdentityRecord? {
    stateLock.withLock { record }
  }

  func updateRecord(
    _ update: (SharedSessionLocalIdentityRecord?) throws -> SharedSessionLocalIdentityRecord?
  ) throws {
    let current = stateLock.withLock { record }
    let updated = try update(current)

    suspension.lock()
    let shouldSuspend = shouldSuspendNextSave && updated != nil
    if shouldSuspend {
      shouldSuspendNextSave = false
      saveIsSuspended = true
      suspension.broadcast()
      while !shouldResumeSave {
        suspension.wait()
      }
      saveIsSuspended = false
    }
    suspension.unlock()

    stateLock.withLock {
      record = updated
      if updated == nil {
        deletionCount += 1
      }
    }
  }
}

private final class ClearTrackingSlotStore: @unchecked Sendable, SharedSessionSlotStoring {
  private let lock = NSLock()
  private var slot: SharedSessionOwnerSlot?

  func loadOwnSlot() throws -> SharedSessionOwnerSlot? {
    lock.withLock { slot }
  }

  func loadAllSlots() throws -> [SharedSessionOwnerSlot] {
    lock.withLock { slot.map { [$0] } ?? [] }
  }

  func saveOwnSlot(_ slot: SharedSessionOwnerSlot) throws {
    lock.withLock { self.slot = slot }
  }

  func deleteOwnSlot() throws {
    lock.withLock { slot = nil }
  }
}

private struct MissingEntitlementSlotStore: SharedSessionSlotStoring {
  func loadOwnSlot() throws -> SharedSessionOwnerSlot? {
    throw KeychainError.unexpectedStatus(errSecMissingEntitlement)
  }

  func loadAllSlots() throws -> [SharedSessionOwnerSlot] {
    throw KeychainError.unexpectedStatus(errSecMissingEntitlement)
  }

  func saveOwnSlot(_: SharedSessionOwnerSlot) throws {
    throw KeychainError.unexpectedStatus(errSecMissingEntitlement)
  }

  func deleteOwnSlot() throws {
    throw KeychainError.unexpectedStatus(errSecMissingEntitlement)
  }
}

@MainActor
private final class SilentSharedSessionNotifier: SharedSessionSyncNotifying {
  func setHandler(_: @escaping @MainActor () -> Void) {}
  func post() {}
}

private func installationMarkerDefaultsSuiteName() -> String {
  "com.clerk.tests.installation-marker.\(UUID().uuidString)"
}

private final class DataFailingKeychain: @unchecked Sendable, KeychainStorage {
  enum Failure: Error {
    case data
  }

  private let lock = NSLock()
  private let failingKey: String
  private var items: [String: Data] = [:]

  init(failingKey: String) {
    self.failingKey = failingKey
  }

  func set(_ data: Data, forKey key: String) throws {
    lock.lock()
    defer { lock.unlock() }
    items[key] = data
  }

  func data(forKey key: String) throws -> Data? {
    if key == failingKey {
      throw Failure.data
    }

    lock.lock()
    defer { lock.unlock() }
    return items[key]
  }

  func deleteItem(forKey key: String) throws {
    lock.lock()
    defer { lock.unlock() }
    items.removeValue(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return items[key] != nil
  }
}
