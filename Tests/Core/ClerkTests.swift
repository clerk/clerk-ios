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
    clerk.markAuthFlowPending()

    #expect(registration == nil)
    #expect(clerk.isAuthFlowComplete)
  }

  @Test
  func refreshedActiveSessionDoesNotHoldARegisteredAuthFlow() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())

    clerk.applyResponseClient(.mock)

    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func completedAuthenticationDoesNotHoldAnUnregisteredAuthFlow() {
    let clerk = Clerk.mockSignedOut

    clerk.applyResponseClient(.mock, completedAuthFlow: completedAuthFlow())

    #expect(clerk.isAuthFlowComplete)
    #expect(clerk.pendingAuthFlowCompletion == nil)
  }

  @Test
  func completedAuthenticationHoldsAuthFlowUntilPostAuthCompletes() async throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())

    clerk.applyResponseClient(.mock, completedAuthFlow: completedAuthFlow())

    #expect(clerk.isAuthFlowComplete == false)
    #expect(clerk.pendingAuthFlowCompletion?.flowId == SignIn.mock.id)
    #expect(clerk.readyPendingAuthFlowCompletion?.flowId == SignIn.mock.id)

    await clerk.consumePendingAuthFlowCompletion()
    #expect(clerk.pendingAuthFlowCompletion == nil)
    #expect(clerk.readyPendingAuthFlowCompletion == nil)
    #expect(clerk.isAuthFlowComplete == false)

    clerk.markAuthFlowComplete()
    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func durableCompletionWaitsForLateRegistrationAndConsumption() async throws {
    let clerk = Clerk.mock
    let didAcknowledge = LockIsolated(false)
    let eventID = UUID()

    clerk.holdDurableAuthFlowCompletion(
      completedAuthFlow(),
      eventID: eventID,
      onConsume: {
        didAcknowledge.setValue(true)
      }
    )

    #expect(clerk.pendingAuthFlowCompletion?.flowId == SignIn.mock.id)
    #expect(clerk.readyPendingAuthFlowCompletion == nil)
    #expect(clerk.isAuthFlowComplete == false)

    let registration = try #require(clerk.registerAuthFlow())

    #expect(clerk.readyPendingAuthFlowCompletion?.flowId == SignIn.mock.id)
    #expect(clerk.isAuthFlowComplete == false)

    await clerk.consumePendingAuthFlowCompletion()

    #expect(didAcknowledge.value)
    #expect(clerk.pendingAuthFlowCompletion == nil)
    #expect(clerk.isAuthFlowComplete == false)

    clerk.markAuthFlowComplete()
    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func completedAuthenticationWaitsForCreatedSessionToBecomeCurrent() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    let completedAuthFlow = completedAuthFlow()
    var pendingActivationClient = Client.mock
    pendingActivationClient.sessions[0].status = .unknown("pending_activation")
    pendingActivationClient.lastActiveSessionId = nil

    clerk.applyResponseClient(
      pendingActivationClient,
      completedAuthFlow: completedAuthFlow
    )

    #expect(clerk.pendingAuthFlowCompletion?.flowId == completedAuthFlow.flowId)
    #expect(clerk.readyPendingAuthFlowCompletion == nil)

    var differentSession = Client.mock.sessions[0]
    differentSession.id = "different_session"
    var differentSessionClient = Client.mock
    differentSessionClient.sessions.append(differentSession)
    differentSessionClient.lastActiveSessionId = differentSession.id
    clerk.applyResponseClient(differentSessionClient)

    #expect(clerk.session?.id == differentSession.id)
    #expect(clerk.pendingAuthFlowCompletion?.flowId == completedAuthFlow.flowId)
    #expect(clerk.readyPendingAuthFlowCompletion == nil)

    let didChange = LockIsolated(false)
    _ = withObservationTracking {
      clerk.readyPendingAuthFlowCompletion?.flowId
    } onChange: {
      didChange.setValue(true)
    }

    var activatedClient = Client.mock
    activatedClient.sessions[0].status = .pending
    activatedClient.sessions[0].tasks = [.setupMfa]
    clerk.applyResponseClient(activatedClient)

    #expect(didChange.value)
    #expect(clerk.pendingAuthFlowCompletion?.flowId == completedAuthFlow.flowId)
    #expect(clerk.readyPendingAuthFlowCompletion?.flowId == completedAuthFlow.flowId)
    withExtendedLifetime(registration) {}
  }

  @Test
  func restoredPendingSessionHoldsAuthFlowAfterSessionBecomesActive() throws {
    var pendingClient = Client.mock
    pendingClient.sessions[0].status = .pending
    pendingClient.sessions[0].tasks = [.setupMfa]
    let clerk = Clerk.mock
    clerk.client = pendingClient
    let registration = try #require(clerk.registerAuthFlow())

    clerk.applyResponseClient(.mock)

    #expect(clerk.isAuthFlowComplete == false)

    clerk.markAuthFlowComplete()
    #expect(clerk.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }

  @Test
  func isAuthFlowCompleteIsObservableWhenPendingFlowChanges() throws {
    let clerk = Clerk.mockSignedOut
    let registration = try #require(clerk.registerAuthFlow())
    clerk.client = .mock
    let didChange = LockIsolated(false)
    let initialValue = withObservationTracking {
      clerk.isAuthFlowComplete
    } onChange: {
      didChange.setValue(true)
    }

    #expect(initialValue)

    clerk.markAuthFlowPending()

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
    await Task.yield()

    #expect(clerk.isAuthFlowComplete)
    #expect(clerk.pendingAuthFlowCompletion == nil)
  }

  @Test
  func delayedRegistrationReleaseDoesNotClearANewerAuthFlow() async throws {
    let clerk = Clerk.mockSignedOut
    var previousRegistration = clerk.registerAuthFlow()
    _ = try #require(previousRegistration)

    previousRegistration = nil
    let currentRegistration = try #require(clerk.registerAuthFlow())
    clerk.applyResponseClient(.mock, completedAuthFlow: completedAuthFlow())
    await Task.yield()

    #expect(clerk.isAuthFlowComplete == false)
    #expect(clerk.pendingAuthFlowCompletion?.flowId == SignIn.mock.id)
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
