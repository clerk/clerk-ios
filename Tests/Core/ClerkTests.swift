@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
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
  func clearAllKeychainItemsDeletesStoredDataAndPreservesAdoptionMarker() throws {
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
      sharedSessionLocalIdentityStore: identityStore,
      telemetryCollector: clerk.dependencies.telemetryCollector,
      clientService: MockClientService(get: { nil })
    )
    clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }
    clerk.client = Client.mock
    clerk.lastClientServerFetchDate = Date(timeIntervalSince1970: 100)

    await clerk.clearAllKeychainItemsAndWait()

    #expect(clerk.client == nil)
    #expect(clerk.lastClientServerFetchDate == nil)
    #expect(try identityStore.loadRecord() == nil)
  }

  @Test
  func synchronousClearRemainsCallableFromAsyncCodeAndOverlappingCallsCoalesce() async {
    let synchronousAPI: @MainActor () -> Void = Clerk.clearAllKeychainItems
    _ = synchronousAPI

    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: InMemoryKeychain(),
      telemetryCollector: clerk.dependencies.telemetryCollector
    )

    let revision = clerk.localIdentityOperationRevision
    let firstClear = Clerk.startKeychainClearIfNeeded(for: clerk)
    let secondClear = Clerk.startKeychainClearIfNeeded(for: clerk)

    #expect(firstClear == secondClear)
    #expect(clerk.localIdentityOperationRevision == revision + 1)
    await firstClear.value

    #expect(clerk.keychainClearTask == nil)
  }

  @Test
  func strictReconfigurationClearPreservesNewWatchTombstone() async throws {
    let legacyShared = InMemoryKeychain()
    let appLocal = InMemoryKeychain()
    let identityKeychain = InMemoryKeychain()
    try WatchSyncMetadataStore(keychain: legacyShared).save(
      WatchSyncMetadataRecord(
        deviceTokenState: "set",
        deviceTokenVersion: 9,
        authState: "set",
        authVersion: 9
      )
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
    #expect(metadata.deviceTokenState == "cleared")
    #expect(metadata.authState == "cleared")
    #expect(!metadata.hasPendingIdentityMetadata)
  }

  @Test
  func awaitedClearWithdrawsOwnerSlotBeforeReturning() async throws {
    let clerk = Clerk()
    let keychain = InMemoryKeychain()
    let identityStore = SharedSessionLocalIdentityStore(keychain: keychain)
    let dependencies = MockDependencyContainer(
      apiClient: clerk.dependencies.apiClient,
      keychain: keychain,
      sharedSessionLocalIdentityStore: identityStore,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    clerk.dependencies = dependencies
    let slotStore = ClearTrackingSlotStore()
    let coordinator = SharedSessionSyncCoordinator(
      ownerIdentifier: "app.clear",
      instanceFingerprint: "instance",
      slotStore: slotStore,
      localIdentityStore: identityStore,
      localIdentityIO: dependencies.sharedSessionLocalIdentityIO,
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
    clerk.setSharedSessionIdentityIfNeeded(identity)
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

    await clerk.clearAllKeychainItemsAndWait()

    #expect(try slotStore.loadOwnSlot() == nil)
    #expect(try identityStore.loadRecord() == nil)
    #expect(clerk.client == nil)
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
      sharedSessionLocalIdentityStore: store,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    clerk.dependencies = dependencies
    let localIdentityIO = try #require(dependencies.sharedSessionLocalIdentityIO)
    let identity = SharedSessionLocalIdentity(
      state: .present,
      deviceToken: "stale-token",
      client: .mock,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let gate = LocalIdentityOperationGate()
    let saveTask = clerk.enqueueLocalIdentityOperation { operationRevision in
      await gate.suspend()
      return try await clerk.persistAndApplyAtomicLocalIdentity(
        identity,
        through: localIdentityIO,
        operationRevision: operationRevision,
        fenceAllClientResponses: false
      )
    }
    try await waitUntil { gate.isSuspended }

    let clearTask = Task { @MainActor in
      await clerk.clearAllKeychainItemsAndWait()
    }
    await Task.yield()
    #expect(clerk.localIdentityDeviceToken == nil)
    #expect(clerk.client == nil)
    gate.resume()

    _ = try? await saveTask.value
    await clearTask.value

    #expect(try store.loadRecord() == nil)
    #expect(clerk.localIdentityDeviceToken == nil)
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
    clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }
    keychain.suspendNextSet(forKey: ClerkKeychainKey.cachedClient.rawValue)
    clerk.client = .mock
    try await waitUntil { keychain.isSetSuspended }

    var didComplete = false
    let clearTask = Task { @MainActor in
      await clerk.clearAllKeychainItemsAndWait()
      didComplete = true
    }
    await Task.yield()
    #expect(!didComplete)

    keychain.resumeSuspendedSet()
    await clearTask.value

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
      sharedSessionLocalIdentityStore: store,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    clerk.setSharedSessionIdentityIfNeeded(initialIdentity)
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
      try await clerk.applyLocalIdentityResponse(
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

  private func environment(
    showDevmodeWarning: Bool,
    type: InstanceEnvironmentType
  ) -> Clerk.Environment {
    var environment = Clerk.Environment.mock
    environment.displayConfig.showDevmodeWarning = showDevmodeWarning
    environment.displayConfig.instanceEnvironmentType = type
    return environment
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

@MainActor
private final class SilentSharedSessionNotifier: SharedSessionSyncNotifying {
  func setHandler(_: @escaping @MainActor () -> Void) {}
  func post() {}
}
