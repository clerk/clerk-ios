@_spi(FrameworkIntegration) @testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct SharedSessionSyncTests {
  @Test
  func activeEnvelopeRoundTripsAsOneKeychainItem() throws {
    let keychain = InMemoryKeychain()
    let store = makeStore(keychain)
    let expectedClient = client(id: "client_1", updatedAt: 100)
    let expectedDate = Date(timeIntervalSince1970: 200)

    let saved = try store.save(
      deviceToken: "device-token",
      client: expectedClient,
      serverDate: expectedDate
    )
    let loaded = try #require(try store.load())

    #expect(loaded == saved)
    #expect(loaded.state == .active)
    #expect(loaded.deviceToken == "device-token")
    #expect(loaded.client == expectedClient)
    #expect(loaded.serverDate == expectedDate)
    #expect(try keychain.hasItem(forKey: store.storageKey))
    #expect(try keychain.data(forKey: ClerkKeychainKey.cachedClient.rawValue) == nil)
    #expect(try keychain.data(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == nil)
  }

  @Test
  func signedOutEnvelopeRoundTripsExplicitly() throws {
    let store = makeStore(InMemoryKeychain())

    let saved = try store.save(
      deviceToken: "device-token",
      client: nil,
      serverDate: Date(timeIntervalSince1970: 200)
    )
    let loaded = try #require(try store.load())

    #expect(loaded == saved)
    #expect(loaded.state == .signedOut)
    #expect(loaded.client == nil)
    #expect(loaded.deviceToken == "device-token")
  }

  @Test
  func activeEnvelopeRequiresDeviceToken() {
    let store = makeStore(InMemoryKeychain())

    #expect(throws: SharedSessionSyncEnvelopeError.self) {
      try store.save(
        deviceToken: nil,
        client: client(id: "client_1", updatedAt: 100),
        serverDate: nil
      )
    }
  }

  @Test
  func envelopeRejectsMismatchedInstance() throws {
    let keychain = InMemoryKeychain()
    let store = makeStore(keychain)
    let envelope = SharedSessionSyncEnvelope(
      schemaVersion: SharedSessionSyncEnvelope.schemaVersion,
      instanceFingerprint: "different-instance",
      revision: UUID(),
      state: .signedOut,
      deviceToken: nil,
      client: nil,
      serverDate: nil
    )
    try keychain.set(
      JSONEncoder.clerkEncoder.encode(envelope),
      forKey: store.storageKey
    )

    #expect(throws: SharedSessionSyncEnvelopeError.self) {
      try store.load()
    }
  }

  @Test
  func namespaceSeparatesClerkInstances() {
    let first = SharedSessionSyncStore(
      keychain: InMemoryKeychain(),
      namespace: SharedSessionSyncNamespace(
        frontendApiUrl: "https://first.clerk.accounts.dev"
      )
    )
    let second = SharedSessionSyncStore(
      keychain: InMemoryKeychain(),
      namespace: SharedSessionSyncNamespace(
        frontendApiUrl: "https://second.clerk.accounts.dev"
      )
    )

    #expect(first.storageKey != second.storageKey)
  }

  @Test
  func adoptionCopiesLegacySharedStateWithoutPublishingEnvelope() throws {
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let legacyClient = client(id: "legacy-client", updatedAt: 100)
    try sharedKeychain.set(
      JSONEncoder.clerkEncoder.encode(legacyClient),
      forKey: ClerkKeychainKey.cachedClient.rawValue
    )
    try sharedKeychain.set(
      "200",
      forKey: ClerkKeychainKey.cachedClientServerDate.rawValue
    )
    try sharedKeychain.set(
      "legacy-token",
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )
    try sharedKeychain.set(
      "set",
      forKey: ClerkKeychainKey.sharedSessionSyncAuthState.rawValue
    )
    try sharedKeychain.set(
      "legacy-auth-revision",
      forKey: ClerkKeychainKey.sharedSessionSyncAuthVersion.rawValue
    )
    try sharedKeychain.set(
      JSONEncoder.clerkEncoder.encode(Clerk.Environment.mock),
      forKey: ClerkKeychainKey.cachedEnvironment.rawValue
    )
    try sharedKeychain.set(
      "legacy-environment-revision",
      forKey: ClerkKeychainKey.sharedSessionSyncEnvironmentVersion.rawValue
    )
    try sharedKeychain.set(
      "set",
      forKey: ClerkKeychainKey.sharedSessionSyncDeviceTokenState.rawValue
    )
    try sharedKeychain.set(
      "legacy-device-token-revision",
      forKey: ClerkKeychainKey.sharedSessionSyncDeviceTokenVersion.rawValue
    )

    try SharedSessionSyncAdoption(
      destination: appLocalKeychain,
      sources: [sharedKeychain],
      legacySharedKeychain: sharedKeychain
    ).migrateIfNeeded()

    let migratedClientData = try #require(
      try appLocalKeychain.data(forKey: ClerkKeychainKey.cachedClient.rawValue)
    )
    #expect(
      try JSONDecoder.clerkDecoder.decode(
        Client.self,
        from: migratedClientData
      ) == legacyClient
    )
    #expect(
      try appLocalKeychain.string(
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      ) == "legacy-token"
    )
    #expect(
      try appLocalKeychain.string(
        forKey: ClerkKeychainKey.cachedClientServerDate.rawValue
      ) == "200"
    )
    #expect(try makeStore(sharedKeychain).load() == nil)
    #expect(try SharedSessionSyncAdoption.isAdopted(in: appLocalKeychain))
    for key in [
      ClerkKeychainKey.cachedClient,
      .cachedClientServerDate,
      .cachedEnvironment,
      .clerkDeviceToken,
      .sharedSessionSyncAuthState,
      .sharedSessionSyncAuthVersion,
      .sharedSessionSyncEnvironmentVersion,
      .sharedSessionSyncDeviceTokenState,
      .sharedSessionSyncDeviceTokenVersion,
    ] {
      #expect(try sharedKeychain.hasItem(forKey: key.rawValue) == false)
    }
  }

  @Test
  func firstAdoptionPreservesExistingAppSessionWithoutPublishingIt() throws {
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let expectedClient = signedInClient(id: "existing-client", updatedAt: 100)
    try seedCache(
      appLocalKeychain,
      deviceToken: "existing-token",
      client: expectedClient,
      serverDate: Date(timeIntervalSince1970: 100),
      environment: .mock
    )

    let clerk = Clerk()
    let dependencies = try makePersistenceDependencies(
      clerk: clerk,
      sharedKeychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain,
      syncEnabled: true,
      refreshedClient: expectedClient
    )
    clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }

    #expect(clerk.client == expectedClient)
    #expect(clerk.deviceToken == "existing-token")
    #expect(clerk.environment == .mock)
    #expect(clerk.isLoaded)
    #expect(try makeStore(sharedKeychain).load() == nil)
    #expect(try SharedSessionSyncAdoption.isAdopted(in: appLocalKeychain))
    #expect(
      try appLocalKeychain.string(
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      ) == "existing-token"
    )
  }

  @Test
  func signedOutSiblingLaunchingFirstDoesNotOverrideMigratedSession() throws {
    let sharedKeychain = InMemoryKeychain()
    let signedOutNotifier = TestSharedSessionSyncNotifier()
    let signedOutClerk = makeIsolatedClerk(
      keychain: sharedKeychain,
      notifier: signedOutNotifier
    )
    let signedOutClient = client(id: "signed-out-client", updatedAt: 100)

    try signedOutClerk.applyResponseClient(
      signedOutClient,
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 100),
      responseDeviceToken: "signed-out-token"
    )

    #expect(signedOutClerk.client == signedOutClient)
    #expect(try makeStore(sharedKeychain).load() == nil)
    #expect(signedOutNotifier.postCount == 0)

    let legacyAppLocalKeychain = InMemoryKeychain()
    let configuredAppLocalKeychain = InMemoryKeychain()
    let stableIdentityKeychain = InMemoryKeychain()
    let expectedSignedInClient = signedInClient(
      id: "existing-signed-in-client",
      updatedAt: 200
    )
    try seedCache(
      legacyAppLocalKeychain,
      deviceToken: "signed-in-token",
      client: expectedSignedInClient,
      serverDate: Date(timeIntervalSince1970: 200),
      environment: .mock
    )

    let signedInClerk = Clerk()
    let signedInDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: signedInClerk.runtimeScope),
      keychain: sharedKeychain,
      appLocalKeychain: configuredAppLocalKeychain,
      identityKeychain: stableIdentityKeychain,
      legacyAppLocalKeychain: legacyAppLocalKeychain,
      clientService: MockClientService(get: { expectedSignedInClient })
    )
    try signedInDependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(
          service: "test.shared.service",
          accessGroup: "test.shared.group"
        ),
        sharedSessionSync: .enabled
      )
    )
    try Clerk.prepareSharedSessionAdoptionIfNeeded(
      dependencies: signedInDependencies
    )
    signedInClerk.performConfiguration(dependencies: signedInDependencies)
    defer { signedInClerk.cleanupManagers() }

    #expect(signedInClerk.client == expectedSignedInClient)
    #expect(signedInClerk.deviceToken == "signed-in-token")
    #expect(try makeStore(sharedKeychain).load() == nil)
    #expect(try SharedSessionSyncAdoption.isAdopted(in: stableIdentityKeychain))

    try signedInClerk.applyResponseClient(
      expectedSignedInClient,
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 200),
      responseDeviceToken: "signed-in-token"
    )

    let envelope = try #require(try makeStore(sharedKeychain).load())
    #expect(envelope.client == expectedSignedInClient)
    #expect(envelope.deviceToken == "signed-in-token")
    #expect(signedOutClerk.sharedSessionSyncCoordinator?.reloadFromSharedStorage(
      force: true,
      to: signedOutClerk
    ) == true)
    #expect(signedOutClerk.client == expectedSignedInClient)
    #expect(signedOutClerk.deviceToken == "signed-in-token")
  }

  @Test
  func sharedLegacyEnvironmentIsCopiedBeforeEnvelopeCleanup() throws {
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let expectedClient = client(id: "shared-client", updatedAt: 200)
    try seedCache(
      sharedKeychain,
      deviceToken: "shared-token",
      client: expectedClient,
      serverDate: Date(timeIntervalSince1970: 200),
      environment: .mock
    )

    let clerk = Clerk()
    let dependencies = try makePersistenceDependencies(
      clerk: clerk,
      sharedKeychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain,
      syncEnabled: true,
      refreshedClient: expectedClient
    )
    clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }

    #expect(clerk.client == expectedClient)
    #expect(clerk.environment == .mock)
    #expect(try makeStore(sharedKeychain).load() == nil)
    #expect(
      try appLocalKeychain.data(
        forKey: ClerkKeychainKey.cachedEnvironment.rawValue
      ) != nil
    )
    #expect(
      try sharedKeychain.data(
        forKey: ClerkKeychainKey.cachedEnvironment.rawValue
      ) == nil
    )
  }

  @Test
  func disablingSyncAfterAdoptionContinuesUsingAppLocalIdentity() throws {
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let expectedClient = client(id: "local-client", updatedAt: 300)
    try seedCache(
      appLocalKeychain,
      deviceToken: "local-token",
      client: expectedClient,
      serverDate: Date(timeIntervalSince1970: 300),
      environment: .mock
    )
    try appLocalKeychain.set(
      "1",
      forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
    )
    try makeStore(sharedKeychain).save(
      deviceToken: "old-shared-token",
      client: client(id: "old-shared-client", updatedAt: 100),
      serverDate: Date(timeIntervalSince1970: 100)
    )

    let clerk = Clerk()
    let dependencies = try makePersistenceDependencies(
      clerk: clerk,
      sharedKeychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain,
      syncEnabled: false,
      refreshedClient: expectedClient
    )
    clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }

    #expect(clerk.sharedSessionSyncCoordinator == nil)
    #expect(clerk.client == expectedClient)
    #expect(clerk.deviceToken == "local-token")
    #expect(clerk.environment == .mock)
  }

  @Test
  func identityTokenReadFailureRequiresRefreshAndRetriesTheRead() throws {
    let identityKeychain = try ReadFailingKeychain(
      deviceToken: "local-token"
    )
    let clerk = makeIsolatedClerk(
      keychain: InMemoryKeychain(),
      notifier: TestSharedSessionSyncNotifier(),
      identityKeychain: identityKeychain
    )

    #expect(clerk.sharedSessionSyncCoordinator?.requiresClientRefresh == true)
    #expect(clerk.deviceToken == "local-token")
    #expect(clerk.sharedSessionSyncCoordinator?.requiresClientRefresh == true)
  }

  @Test
  func identityTokenReadRecoveryReconcilesBeforePreparingRequest() async throws {
    configureClerkForTesting()
    let sharedKeychain = InMemoryKeychain()
    let identityKeychain = try ReadFailingKeychain(
      deviceToken: "local-token",
      failureCount: 2
    )
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = Clerk()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: sharedKeychain,
      appLocalKeychain: InMemoryKeychain(),
      identityKeychain: identityKeychain
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(
          service: "test.service",
          accessGroup: "test.group"
        ),
        sharedSessionSync: .enabled
      )
    )
    clerk.dependencies = dependencies

    let localClient = signedInClient(id: "local-client", updatedAt: 100)
    let localServerDate = Date(timeIntervalSince1970: 100)
    clerk.lastClientServerFetchDate = localServerDate
    clerk.client = localClient
    try makeStore(sharedKeychain).save(
      deviceToken: nil,
      client: nil,
      serverDate: nil
    )

    let coordinator = SharedSessionSyncCoordinator(
      keychainConfig: dependencies.configurationManager.options.keychainConfig,
      namespace: namespace,
      clerk: clerk,
      keychain: sharedKeychain,
      identityKeychain: identityKeychain,
      notifier: notifier
    )
    clerk.sharedSessionSyncCoordinator = coordinator
    clerk.internalStateChanges.addObserver(coordinator)

    #expect(clerk.client == localClient)
    #expect(clerk.lastClientServerFetchDate == localServerDate)
    #expect(coordinator.requiresClientRefresh)

    notifier.simulateNotification()

    #expect(clerk.client == localClient)
    #expect(clerk.lastClientServerFetchDate == localServerDate)
    #expect(coordinator.requiresClientRefresh)

    let middleware = ClerkHeaderRequestMiddleware(runtimeScope: clerk.runtimeScope)
    var request = try URLRequest(url: #require(URL(string: "https://example.com/v1/client")))
    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(request.clerkClientResponseGeneration == clerk.clientResponseGeneration)
    #expect(clerk.deviceToken == nil)
    #expect(clerk.client == nil)
    #expect(clerk.lastClientServerFetchDate == nil)
    #expect(!coordinator.requiresClientRefresh)
  }

  @Test
  func failedInitialEnvelopeApplicationCannotPublishStaleLocalIdentity() throws {
    configureClerkForTesting()
    let sharedKeychain = InMemoryKeychain()
    let identityKeychain = ControllableSetFailingKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = Clerk()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: sharedKeychain,
      appLocalKeychain: InMemoryKeychain(),
      identityKeychain: identityKeychain
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(
          service: "test.service",
          accessGroup: "test.group"
        ),
        sharedSessionSync: .enabled
      )
    )
    clerk.dependencies = dependencies

    let localClient = signedInClient(id: "local-client", updatedAt: 100)
    let changedLocalClient = signedInClient(id: "changed-local-client", updatedAt: 150)
    let sharedClient = signedInClient(id: "shared-client", updatedAt: 200)
    try identityKeychain.set(
      "local-token",
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )
    clerk.lastClientServerFetchDate = Date(timeIntervalSince1970: 100)
    clerk.client = localClient
    let sharedEnvelope = try makeStore(sharedKeychain).save(
      deviceToken: "shared-token",
      client: sharedClient,
      serverDate: Date(timeIntervalSince1970: 200)
    )

    identityKeychain.setShouldFail(true)
    let coordinator = SharedSessionSyncCoordinator(
      keychainConfig: dependencies.configurationManager.options.keychainConfig,
      namespace: namespace,
      clerk: clerk,
      keychain: sharedKeychain,
      identityKeychain: identityKeychain,
      notifier: notifier
    )
    clerk.sharedSessionSyncCoordinator = coordinator
    clerk.internalStateChanges.addObserver(coordinator)

    clerk.lastClientServerFetchDate = Date(timeIntervalSince1970: 150)
    clerk.client = changedLocalClient

    #expect(try makeStore(sharedKeychain).load() == sharedEnvelope)
    #expect(notifier.postCount == 0)

    identityKeychain.setShouldFail(false)
    clerk.emitInternalStateChange(.applicationDidEnterForeground)

    #expect(clerk.deviceToken == "shared-token")
    #expect(clerk.client == sharedClient)
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 200))
    #expect(try makeStore(sharedKeychain).load() == sharedEnvelope)
    #expect(notifier.postCount == 0)
  }

  @Test
  func failedRuntimeEnvelopeApplicationCannotPublishStaleLocalIdentity() throws {
    configureClerkForTesting()
    let sharedKeychain = InMemoryKeychain()
    let identityKeychain = ControllableSetFailingKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = Clerk()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: sharedKeychain,
      appLocalKeychain: InMemoryKeychain(),
      identityKeychain: identityKeychain
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(
          service: "test.service",
          accessGroup: "test.group"
        ),
        sharedSessionSync: .enabled
      )
    )
    clerk.dependencies = dependencies

    let localClient = signedInClient(id: "local-client", updatedAt: 100)
    let changedLocalClient = signedInClient(id: "changed-local-client", updatedAt: 150)
    let sharedClient = signedInClient(id: "shared-client", updatedAt: 200)
    try identityKeychain.set(
      "local-token",
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )
    clerk.lastClientServerFetchDate = Date(timeIntervalSince1970: 100)
    clerk.client = localClient

    let coordinator = SharedSessionSyncCoordinator(
      keychainConfig: dependencies.configurationManager.options.keychainConfig,
      namespace: namespace,
      clerk: clerk,
      keychain: sharedKeychain,
      identityKeychain: identityKeychain,
      notifier: notifier
    )
    clerk.sharedSessionSyncCoordinator = coordinator
    clerk.internalStateChanges.addObserver(coordinator)

    let sharedEnvelope = try makeStore(sharedKeychain).save(
      deviceToken: "shared-token",
      client: sharedClient,
      serverDate: Date(timeIntervalSince1970: 200)
    )
    identityKeychain.setShouldFail(true)
    notifier.simulateNotification()

    #expect(clerk.deviceToken == "local-token")
    #expect(clerk.client == localClient)
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 100))

    clerk.lastClientServerFetchDate = Date(timeIntervalSince1970: 150)
    clerk.client = changedLocalClient

    #expect(try makeStore(sharedKeychain).load() == sharedEnvelope)
    #expect(notifier.postCount == 0)

    identityKeychain.setShouldFail(false)
    notifier.simulateNotification()

    #expect(clerk.deviceToken == "shared-token")
    #expect(clerk.client == sharedClient)
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 200))
    #expect(try makeStore(sharedKeychain).load() == sharedEnvelope)
    #expect(notifier.postCount == 0)
  }

  @Test
  func startupDefersProvablyOlderSharedEnvelopeUntilClientRefresh() async throws {
    let notifier = TestSharedSessionSyncNotifier()
    let state = try makeStaleStartupState(notifier: notifier)

    #expect(state.clerk.client == state.localClient)
    #expect(state.clerk.deviceToken == "local-token")
    #expect(state.coordinator.requiresClientRefresh)
    #expect(try makeStore(state.sharedKeychain).load() == state.sharedEnvelope)
    #expect(notifier.postCount == 0)

    let middleware = ClerkHeaderRequestMiddleware(
      runtimeScope: .current(clerkProvider: { state.clerk })
    )
    var request = try URLRequest(
      url: #require(URL(string: "https://example.com/v1/client"))
    )
    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "Authorization") == "local-token")
    #expect(request.value(forHTTPHeaderField: "x-clerk-client-id") == nil)

    let refreshedClient = client(id: "refreshed-client", updatedAt: 400)
    state.clerk.applyResponseClient(
      refreshedClient,
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 400)
    )

    #expect(!state.coordinator.requiresClientRefresh)
    #expect(state.clerk.client == refreshedClient)
    let published = try #require(try makeStore(state.sharedKeychain).load())
    #expect(published.revision != state.sharedEnvelope.revision)
    #expect(published.deviceToken == "local-token")
    #expect(published.client == refreshedClient)
    #expect(published.serverDate == Date(timeIntervalSince1970: 400))
    #expect(notifier.postCount == 1)
  }

  @Test
  func staleStartupDoesNotPublishTokenOnlyOrForcedReload() async throws {
    let notifier = TestSharedSessionSyncNotifier()
    let state = try makeStaleStartupState(notifier: notifier)
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": "new-token"]
    ))
    var request = URLRequest(url: url)
    request.setClerkClientResponseGeneration(
      state.clerk.clientResponseGeneration
    )

    try await ClerkDeviceTokenResponseMiddleware(
      runtimeScope: .current(clerkProvider: { state.clerk })
    ).validate(response, data: Data(), for: request)

    #expect(state.coordinator.requiresClientRefresh)
    #expect(state.clerk.deviceToken == "new-token")
    #expect(try makeStore(state.sharedKeychain).load() == state.sharedEnvelope)
    #expect(notifier.postCount == 0)

    #expect(
      state.coordinator.reloadFromSharedStorage(
        force: true,
        to: state.clerk
      ) == false
    )
    #expect(state.coordinator.requiresClientRefresh)
    #expect(try makeStore(state.sharedKeychain).load() == state.sharedEnvelope)
    #expect(notifier.postCount == 0)
  }

  @Test
  func clearingKeychainInvalidatesLiveSharedTokenAndFencesResponses() async throws {
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(
      keychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain,
      notifier: notifier
    )
    let localClient = signedInClient(id: "local-client", updatedAt: 100)

    try clerk.storeDeviceToken("device-token")
    clerk.applyResponseClient(
      localClient,
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let initialGeneration = clerk.clientResponseGeneration
    #expect(try makeStore(sharedKeychain).load() != nil)

    Clerk.clearAllKeychainItems(in: clerk)

    #expect(clerk.client == localClient)
    #expect(clerk.deviceToken == nil)
    #expect(clerk.clientResponseGeneration != initialGeneration)
    #expect(clerk.sharedSessionSyncCoordinator?.requiresClientRefresh == true)
    #expect(try makeStore(sharedKeychain).load() == nil)
    #expect(
      try appLocalKeychain.string(
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      ) == nil
    )

    let middleware = ClerkHeaderRequestMiddleware(
      runtimeScope: .current(clerkProvider: { clerk })
    )
    var request = try URLRequest(
      url: #require(URL(string: "https://example.com/v1/client"))
    )
    try await middleware.prepare(&request)

    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    #expect(request.value(forHTTPHeaderField: "x-clerk-client-id") == nil)
  }

  @Test
  func reenablingSyncAppliesNewerSharedEnvelope() throws {
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let localClient = client(id: "local-client", updatedAt: 100)
    let sharedClient = client(id: "shared-client", updatedAt: 300)
    try seedCache(
      appLocalKeychain,
      deviceToken: "local-token",
      client: localClient,
      serverDate: Date(timeIntervalSince1970: 100),
      environment: .mock
    )
    try appLocalKeychain.set(
      "1",
      forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
    )
    try makeStore(sharedKeychain).save(
      deviceToken: "shared-token",
      client: sharedClient,
      serverDate: Date(timeIntervalSince1970: 300)
    )

    let clerk = Clerk()
    let dependencies = try makePersistenceDependencies(
      clerk: clerk,
      sharedKeychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain,
      syncEnabled: true,
      refreshedClient: sharedClient
    )
    clerk.performConfiguration(dependencies: dependencies)
    defer { clerk.cleanupManagers() }

    #expect(clerk.client == sharedClient)
    #expect(clerk.deviceToken == "shared-token")
    #expect(
      try appLocalKeychain.string(
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      ) == "shared-token"
    )
  }

  @Test
  func reenablingSyncWithoutSharedEnvelopeKeepsLocalIdentityProvisional() throws {
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let localClient = client(id: "local-client", updatedAt: 300)
    try seedCache(
      appLocalKeychain,
      deviceToken: "local-token",
      client: localClient,
      serverDate: Date(timeIntervalSince1970: 300),
      environment: .mock
    )
    try appLocalKeychain.set(
      "1",
      forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
    )
    let reenabledClerk = Clerk()
    let reenabledDependencies = try makePersistenceDependencies(
      clerk: reenabledClerk,
      sharedKeychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain,
      syncEnabled: true,
      refreshedClient: localClient
    )
    reenabledClerk.performConfiguration(
      dependencies: reenabledDependencies
    )
    defer { reenabledClerk.cleanupManagers() }

    #expect(reenabledClerk.client == localClient)
    #expect(reenabledClerk.deviceToken == "local-token")
    #expect(reenabledClerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 300))
    #expect(try makeStore(sharedKeychain).load() == nil)
  }

  @Test
  func ordinaryAccessGroupStorageRemainsSharedUntilSyncIsAdopted() throws {
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()

    let ordinaryIdentity = try SharedSessionSyncAdoption.identityKeychain(
      shared: sharedKeychain,
      appLocal: appLocalKeychain,
      syncEnabled: false
    )
    try ordinaryIdentity.set("shared", forKey: "identity-selection")
    #expect(try sharedKeychain.string(forKey: "identity-selection") == "shared")
    #expect(try appLocalKeychain.string(forKey: "identity-selection") == nil)

    try appLocalKeychain.set(
      "1",
      forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
    )
    let adoptedIdentity = try SharedSessionSyncAdoption.identityKeychain(
      shared: sharedKeychain,
      appLocal: appLocalKeychain,
      syncEnabled: false
    )
    try adoptedIdentity.set("local", forKey: "identity-selection")
    #expect(try appLocalKeychain.string(forKey: "identity-selection") == "local")
  }

  @Test
  func adoptedIdentityRemainsStableWhenConfiguredSharedStorageChanges() throws {
    let stableIdentityKeychain = InMemoryKeychain()
    let customSharedKeychain = InMemoryKeychain()
    let defaultSharedKeychain = InMemoryKeychain()
    try stableIdentityKeychain.set(
      "1",
      forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
    )

    let beforeConfigurationRemoval = try SharedSessionSyncAdoption.identityKeychain(
      shared: customSharedKeychain,
      appLocal: stableIdentityKeychain,
      syncEnabled: false
    )
    try beforeConfigurationRemoval.set(
      "stable",
      forKey: "identity-selection"
    )

    let afterConfigurationRemoval = try SharedSessionSyncAdoption.identityKeychain(
      shared: defaultSharedKeychain,
      appLocal: stableIdentityKeychain,
      syncEnabled: false
    )

    #expect(
      try afterConfigurationRemoval.string(
        forKey: "identity-selection"
      ) == "stable"
    )
    #expect(
      try defaultSharedKeychain.string(
        forKey: "identity-selection"
      ) == nil
    )
  }

  @Test
  func clearingAuthenticationPreservesAdoptedStorageRouting() throws {
    let sharedKeychain = InMemoryKeychain()
    let stableIdentityKeychain = InMemoryKeychain()
    try stableIdentityKeychain.set(
      "1",
      forKey: ClerkKeychainKey.sharedSessionSyncAdopted.rawValue
    )
    try stableIdentityKeychain.set(
      "old-token",
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )

    try Clerk.clearAllKeychainItemsStrictly(in: stableIdentityKeychain)

    #expect(try SharedSessionSyncAdoption.isAdopted(in: stableIdentityKeychain))
    #expect(
      try stableIdentityKeychain.string(
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      ) == nil
    )

    let selectedIdentity = try SharedSessionSyncAdoption.identityKeychain(
      shared: sharedKeychain,
      appLocal: stableIdentityKeychain,
      syncEnabled: false
    )
    try selectedIdentity.set(
      "new-token",
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )

    let relaunchedIdentity = try SharedSessionSyncAdoption.identityKeychain(
      shared: sharedKeychain,
      appLocal: stableIdentityKeychain,
      syncEnabled: false
    )
    #expect(
      try relaunchedIdentity.string(
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      ) == "new-token"
    )
    #expect(
      try sharedKeychain.string(
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      ) == nil
    )
  }

  @Test
  func adoptionMarkerReadFailureDoesNotFallbackToSharedIdentity() {
    #expect(throws: SharedSessionSyncTestError.self) {
      _ = try SharedSessionSyncAdoption.identityKeychain(
        shared: InMemoryKeychain(),
        appLocal: FailingKeychain(),
        syncEnabled: false
      )
    }
  }

  @Test
  func adoptionMigrationFailureDoesNotContinueWithAnEmptyLocalCache() throws {
    let appLocalKeychain = InMemoryKeychain()

    #expect(throws: SharedSessionSyncTestError.self) {
      try SharedSessionSyncAdoption(
        destination: appLocalKeychain,
        sources: [FailingKeychain()],
        legacySharedKeychain: InMemoryKeychain()
      ).migrateIfNeeded()
    }
    #expect(
      try !SharedSessionSyncAdoption.isAdopted(in: appLocalKeychain)
    )
  }

  @Test
  func deviceTokenAloneDoesNotPublishPartialIdentity() throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(keychain: keychain, notifier: notifier)

    try clerk.storeDeviceToken("device-token")

    #expect(try makeStore(keychain).load() == nil)
    #expect(notifier.postCount == 0)
  }

  @Test
  func tokenOnlyResponsePersistsCurrentIdentity() async throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(keychain: keychain, notifier: notifier)
    let expectedClient = signedInClient(id: "client_1", updatedAt: 100)

    try clerk.storeDeviceToken("old-token")
    clerk.applyResponseClient(
      expectedClient,
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 100)
    )

    let url = try #require(URL(string: "https://example.com/v1/client"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: ["Authorization": "new-token"]
    ))
    var request = URLRequest(url: url)
    request.setClerkClientResponseGeneration(clerk.clientResponseGeneration)

    try await ClerkDeviceTokenResponseMiddleware(
      runtimeScope: .current(clerkProvider: { clerk })
    ).validate(response, data: Data(), for: request)

    let envelope = try #require(try makeStore(keychain).load())
    #expect(envelope.deviceToken == "new-token")
    #expect(envelope.client == expectedClient)
    #expect(envelope.serverDate == Date(timeIntervalSince1970: 100))
    #expect(notifier.postCount == 2)

    let relaunched = makeIsolatedClerk(
      keychain: keychain,
      notifier: TestSharedSessionSyncNotifier()
    )
    #expect(relaunched.sharedSessionSyncCoordinator?.deviceToken == "new-token")
    #expect(relaunched.client == expectedClient)
    #expect(relaunched.lastClientServerFetchDate == Date(timeIntervalSince1970: 100))
  }

  @Test
  func responseClientPublishesOneCompleteEnvelope() async throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(keychain: keychain, notifier: notifier)
    let expectedClient = signedInClient(id: "client_1", updatedAt: 100)
    let data = try JSONEncoder.clerkEncoder.encode(expectedClient)
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let response = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: [
        "Authorization": "device-token",
        "Date": "Thu, 01 Jan 1970 00:03:20 GMT",
      ]
    ))
    var request = URLRequest(url: url)
    request.setClerkClientResponseGeneration(clerk.clientResponseGeneration)

    try await ClerkDeviceTokenResponseMiddleware(
      runtimeScope: .current(clerkProvider: { clerk })
    ).validate(response, data: data, for: request)

    #expect(try makeStore(keychain).load() == nil)
    #expect(notifier.postCount == 0)

    try await ClerkClientSyncResponseMiddleware(
      runtimeScope: .current(clerkProvider: { clerk })
    ).validate(response, data: data, for: request)

    let envelope = try #require(try makeStore(keychain).load())
    #expect(envelope.deviceToken == "device-token")
    #expect(envelope.client == expectedClient)
    #expect(envelope.serverDate == Date(timeIntervalSince1970: 200))
    #expect(notifier.postCount == 1)
  }

  @Test
  func rejectedOlderClientResponseDoesNotReplaceAcceptedDeviceToken() async throws {
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(
      keychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain,
      notifier: notifier
    )
    let tokenMiddleware = ClerkDeviceTokenResponseMiddleware(
      runtimeScope: .current(clerkProvider: { clerk })
    )
    let clientMiddleware = ClerkClientSyncResponseMiddleware(
      runtimeScope: .current(clerkProvider: { clerk })
    )
    let url = try #require(URL(string: "https://example.com/v1/client"))
    let newerClient = signedInClient(id: "newer-client", updatedAt: 200)
    let olderClient = signedInClient(id: "older-client", updatedAt: 100)
    let newerData = try JSONEncoder.clerkEncoder.encode(newerClient)
    let olderData = try JSONEncoder.clerkEncoder.encode(olderClient)
    let newerResponse = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: [
        "Authorization": "newer-token",
        "Date": "Thu, 01 Jan 1970 00:03:20 GMT",
      ]
    ))
    let olderResponse = try #require(HTTPURLResponse(
      url: url,
      statusCode: 200,
      httpVersion: nil,
      headerFields: [
        "Authorization": "older-token",
        "Date": "Thu, 01 Jan 1970 00:01:40 GMT",
      ]
    ))
    var newerRequest = URLRequest(url: url)
    newerRequest.setClerkRequestSequence(2)
    newerRequest.setClerkClientResponseGeneration(
      clerk.clientResponseGeneration
    )
    var olderRequest = URLRequest(url: url)
    olderRequest.setClerkRequestSequence(1)
    olderRequest.setClerkClientResponseGeneration(
      clerk.clientResponseGeneration
    )

    try await tokenMiddleware.validate(
      newerResponse,
      data: newerData,
      for: newerRequest
    )
    try await clientMiddleware.validate(
      newerResponse,
      data: newerData,
      for: newerRequest
    )
    try await tokenMiddleware.validate(
      olderResponse,
      data: olderData,
      for: olderRequest
    )
    try await clientMiddleware.validate(
      olderResponse,
      data: olderData,
      for: olderRequest
    )

    #expect(clerk.client == newerClient)
    #expect(clerk.deviceToken == "newer-token")
    #expect(
      try appLocalKeychain.string(
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      ) == "newer-token"
    )
    let envelope = try #require(try makeStore(sharedKeychain).load())
    #expect(envelope.client == newerClient)
    #expect(envelope.deviceToken == "newer-token")
    #expect(envelope.serverDate == Date(timeIntervalSince1970: 200))
    #expect(notifier.postCount == 1)
  }

  @Test
  func refreshClientRetriesAfterDeviceTokenPersistenceFailure() async throws {
    let sharedKeychain = InMemoryKeychain()
    let identityKeychain = ControllableSetFailingKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = Clerk()
    let apiClient = createMockAPIClient(runtimeScope: clerk.runtimeScope)
    let dependencies = MockDependencyContainer(
      apiClient: apiClient,
      keychain: sharedKeychain,
      identityKeychain: identityKeychain,
      clientService: ClientService(apiClient: apiClient)
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(
          service: "test.service",
          accessGroup: "test.group"
        ),
        sharedSessionSync: .enabled
      )
    )
    clerk.dependencies = dependencies
    let coordinator = SharedSessionSyncCoordinator(
      keychainConfig: dependencies.configurationManager.options.keychainConfig,
      namespace: namespace,
      clerk: clerk,
      keychain: sharedKeychain,
      identityKeychain: identityKeychain,
      notifier: notifier
    )
    clerk.sharedSessionSyncCoordinator = coordinator
    clerk.internalStateChanges.addObserver(coordinator)

    let expectedClient = signedInClient(id: "client_1", updatedAt: 100)
    let requestCount = LockIsolated(0)
    let url = try #require(URL(string: mockBaseUrl.absoluteString + "/v1/client"))
    var mock = try Mock(
      url: url,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(
          ClientResponse<Client?>(
            response: expectedClient,
            client: expectedClient
          )
        ),
      ],
      additionalHeaders: [
        "Authorization": "device-token",
        "Date": "Thu, 01 Jan 1970 00:01:40 GMT",
      ]
    )
    mock.onRequestHandler = OnRequestHandler { @Sendable _ in
      let attempt = requestCount.withValue {
        $0 += 1
        return $0
      }
      if attempt == 2 {
        identityKeychain.setShouldFail(false)
      }
    }
    mock.register()

    identityKeychain.setShouldFail(true)
    let refreshedClient = try await retryingOperation(
      policy: RetryPolicy(
        maxAttempts: 2,
        initialDelay: .zero,
        maximumDelay: .zero
      ),
      operationName: "test client refresh"
    ) {
      try await clerk.refreshClient()
    }

    #expect(requestCount.value == 2)
    #expect(refreshedClient == expectedClient)
    #expect(clerk.client == expectedClient)
    #expect(clerk.deviceToken == "device-token")
    let envelope = try #require(try makeStore(sharedKeychain).load())
    #expect(envelope.client == expectedClient)
    #expect(envelope.deviceToken == "device-token")
    #expect(envelope.serverDate == Date(timeIntervalSince1970: 100))
    #expect(notifier.postCount == 1)
  }

  @Test
  func failedDeviceTokenRefreshKeepsClearedTransitionDurable() async throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(
      keychain: keychain,
      notifier: notifier,
      clientService: MockClientService(get: {
        throw SharedSessionSyncTestError.refreshFailed
      })
    )

    try clerk.storeDeviceToken("old-token")
    clerk.applyResponseClient(
      signedInClient(id: "old-client", updatedAt: 100),
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 100)
    )

    await #expect(throws: SharedSessionSyncTestError.refreshFailed) {
      try await clerk.updateDeviceToken("new-token")
    }

    let transition = try #require(try makeStore(keychain).load())
    #expect(transition.state == .signedOut)
    #expect(transition.deviceToken == "new-token")
    #expect(transition.client == nil)
    #expect(transition.serverDate == nil)

    let relaunched = makeIsolatedClerk(
      keychain: keychain,
      notifier: TestSharedSessionSyncNotifier()
    )
    #expect(relaunched.sharedSessionSyncCoordinator?.deviceToken == "new-token")
    #expect(relaunched.client == nil)
    #expect(relaunched.lastClientServerFetchDate == nil)
  }

  @Test
  func watchPayloadReadsDeviceTokenFromSharedEnvelopeCoordinator() throws {
    let keychain = InMemoryKeychain()
    let clerk = makeIsolatedClerk(
      keychain: keychain,
      notifier: TestSharedSessionSyncNotifier()
    )

    try clerk.storeDeviceToken("device-token")
    let payload = WatchSyncPayload(
      clerk: clerk,
      keychain: clerk.dependencies.appLocalKeychain,
      authGeneration: .initial
    )

    #expect(payload.deviceToken == "device-token")
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == nil)
  }

  @Test
  func standaloneWatchDeviceTokenPersistsAcrossRelaunch() throws {
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    try makeStore(sharedKeychain).save(
      deviceToken: "existing-token",
      client: nil,
      serverDate: nil
    )
    let clerk = makeIsolatedClerk(
      keychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain,
      notifier: notifier
    )
    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "watch-token",
        version: WatchSyncVersion(rawValue: 1)
      ),
      clientUpdate: .notIncluded,
      environment: nil
    )

    WatchConnectivityCoordinator().apply(payload, from: .watch, to: clerk)

    let envelope = try #require(try makeStore(sharedKeychain).load())
    #expect(envelope.state == .signedOut)
    #expect(envelope.deviceToken == "watch-token")
    #expect(envelope.client == nil)
    #expect(envelope.serverDate == nil)
    #expect(notifier.postCount == 1)

    let relaunched = makeIsolatedClerk(
      keychain: sharedKeychain,
      appLocalKeychain: InMemoryKeychain(),
      notifier: TestSharedSessionSyncNotifier()
    )
    #expect(relaunched.sharedSessionSyncCoordinator?.deviceToken == "watch-token")
    #expect(relaunched.client == nil)
  }

  @Test
  func clientChangePublishesCompleteEnvelopeOnce() throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(keychain: keychain, notifier: notifier)
    let expectedClient = signedInClient(id: "client_1", updatedAt: 100)

    try clerk.storeDeviceToken("device-token")
    clerk.applyResponseClient(
      expectedClient,
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 200)
    )

    let envelope = try #require(try makeStore(keychain).load())
    #expect(envelope.state == .active)
    #expect(envelope.deviceToken == "device-token")
    #expect(envelope.client == expectedClient)
    #expect(envelope.serverDate == Date(timeIntervalSince1970: 200))
    #expect(notifier.postCount == 1)
  }

  @Test
  func signOutPublishesExplicitSignedOutEnvelope() throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(keychain: keychain, notifier: notifier)

    try clerk.storeDeviceToken("device-token")
    clerk.applyResponseClient(
      signedInClient(id: "client_1", updatedAt: 100),
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    clerk.applyResponseClient(
      nil,
      responseSequence: 2,
      serverDate: Date(timeIntervalSince1970: 200)
    )

    let envelope = try #require(try makeStore(keychain).load())
    #expect(envelope.state == .signedOut)
    #expect(envelope.client == nil)
    #expect(envelope.deviceToken == "device-token")
    #expect(envelope.serverDate == Date(timeIntervalSince1970: 200))
    #expect(notifier.postCount == 2)
  }

  @Test
  func notificationAppliesEnvelopeWithoutEchoAndFencesResponsesForNewToken() throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(keychain: keychain, notifier: notifier)

    try clerk.storeDeviceToken("local-token")
    clerk.applyResponseClient(
      client(id: "local-client", updatedAt: 100),
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let initialGeneration = clerk.clientResponseGeneration
    let initialPostCount = notifier.postCount

    try makeStore(keychain).save(
      deviceToken: "shared-token",
      client: client(id: "shared-client", updatedAt: 200),
      serverDate: Date(timeIntervalSince1970: 200)
    )
    notifier.simulateNotification()

    #expect(clerk.client?.id == "shared-client")
    #expect(clerk.sharedSessionSyncCoordinator?.deviceToken == "shared-token")
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 200))
    #expect(clerk.clientResponseGeneration != initialGeneration)
    #expect(notifier.postCount == initialPostCount)
  }

  @Test
  func differentTokenSignedOutEnvelopeClearsCachedClientMetadata() async throws {
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(
      keychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain,
      notifier: notifier
    )
    let cacheManager = CacheManager(
      coordinator: clerk,
      keychain: appLocalKeychain
    )
    clerk.cacheManager = cacheManager

    try clerk.storeDeviceToken("local-token")
    clerk.applyResponseClient(
      client(id: "local-client", updatedAt: 100),
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    clerk.environment = Clerk.Environment.mock

    try makeStore(sharedKeychain).save(
      deviceToken: "shared-token",
      client: nil,
      serverDate: nil
    )
    notifier.simulateNotification()
    await cacheManager.shutdownAndDrain()

    #expect(clerk.client == nil)
    #expect(clerk.lastClientServerFetchDate == nil)
    for key in [
      ClerkKeychainKey.cachedClient,
      .cachedClientServerDate,
      .cachedEnvironment,
    ] {
      #expect(try appLocalKeychain.data(forKey: key.rawValue) == nil)
    }
  }

  @Test
  func sameTokenEnvelopeAllowsProvablyNewerFencedResponse() throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(keychain: keychain, notifier: notifier)

    try clerk.storeDeviceToken("device-token")
    clerk.applyResponseClient(
      client(id: "local-client", updatedAt: 100),
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let initialGeneration = clerk.clientResponseGeneration
    let initialPostCount = notifier.postCount

    try makeStore(keychain).save(
      deviceToken: "device-token",
      client: client(id: "shared-client", updatedAt: 200),
      serverDate: Date(timeIntervalSince1970: 200)
    )
    notifier.simulateNotification()

    #expect(clerk.client?.id == "shared-client")
    #expect(clerk.clientResponseGeneration != initialGeneration)
    #expect(notifier.postCount == initialPostCount)

    let newerClient = client(id: "newer-client", updatedAt: 300)
    clerk.applyResponseClient(
      newerClient,
      responseSequence: 2,
      serverDate: Date(timeIntervalSince1970: 300),
      clientResponseGeneration: initialGeneration
    )

    #expect(clerk.client == newerClient)
    let published = try #require(try makeStore(keychain).load())
    #expect(published.client == newerClient)
    #expect(published.serverDate == Date(timeIntervalSince1970: 300))
    #expect(notifier.postCount == initialPostCount + 1)
  }

  @Test
  func sameTokenEnvelopeRejectsOlderFencedResponse() throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(keychain: keychain, notifier: notifier)
    let staleClient = client(id: "stale-client", updatedAt: 200)

    try clerk.storeDeviceToken("device-token")
    clerk.applyResponseClient(
      client(id: "local-client", updatedAt: 100),
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let requestGeneration = clerk.clientResponseGeneration
    let initialPostCount = notifier.postCount

    try makeStore(keychain).save(
      deviceToken: "device-token",
      client: nil,
      serverDate: Date(timeIntervalSince1970: 300)
    )
    notifier.simulateNotification()

    #expect(clerk.client == nil)
    #expect(clerk.clientResponseGeneration != requestGeneration)

    let didApply = clerk.applyResponseClient(
      staleClient,
      responseSequence: 2,
      serverDate: Date(timeIntervalSince1970: 200),
      clientResponseGeneration: requestGeneration
    )

    #expect(!didApply)
    #expect(clerk.client == nil)
    let published = try #require(try makeStore(keychain).load())
    #expect(published.state == .signedOut)
    #expect(published.client == nil)
    #expect(published.serverDate == Date(timeIntervalSince1970: 300))
    #expect(notifier.postCount == initialPostCount)
  }

  @Test
  func provablyOlderSharedWriteIsRejectedAndRepaired() throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(keychain: keychain, notifier: notifier)
    let localClient = client(id: "local-client", updatedAt: 300)

    try clerk.storeDeviceToken("local-token")
    clerk.applyResponseClient(
      localClient,
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 300)
    )
    let initialPostCount = notifier.postCount

    let staleEnvelope = try makeStore(keychain).save(
      deviceToken: "stale-token",
      client: client(id: "stale-client", updatedAt: 100),
      serverDate: Date(timeIntervalSince1970: 100)
    )
    notifier.simulateNotification()

    #expect(clerk.client == localClient)
    #expect(clerk.sharedSessionSyncCoordinator?.deviceToken == "local-token")
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 300))
    #expect(notifier.postCount == initialPostCount + 1)

    let repaired = try #require(try makeStore(keychain).load())
    #expect(repaired.revision != staleEnvelope.revision)
    #expect(repaired.client == localClient)
    #expect(repaired.deviceToken == "local-token")
    #expect(repaired.serverDate == Date(timeIntervalSince1970: 300))
  }

  @Test
  func envelopeApplicationRetriesAfterIdentityTokenPersistenceFailure() throws {
    let sharedKeychain = InMemoryKeychain()
    let identityKeychain = ControllableSetFailingKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(
      keychain: sharedKeychain,
      notifier: notifier,
      identityKeychain: identityKeychain
    )
    let expectedClient = client(id: "shared-client", updatedAt: 200)

    try makeStore(sharedKeychain).save(
      deviceToken: "shared-token",
      client: expectedClient,
      serverDate: Date(timeIntervalSince1970: 200)
    )
    identityKeychain.setShouldFail(true)
    notifier.simulateNotification()

    #expect(clerk.client == nil)
    #expect(clerk.deviceToken == nil)

    identityKeychain.setShouldFail(false)
    notifier.simulateNotification()

    #expect(clerk.client == expectedClient)
    #expect(clerk.deviceToken == "shared-token")
    #expect(
      try identityKeychain.string(
        forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
      ) == "shared-token"
    )
    #expect(notifier.postCount == 0)
  }

  @Test
  func equalDateActiveEnvelopeAppliesLastCompleteWrite() throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let serverDate = Date(timeIntervalSince1970: 200)
    let clerk = makeIsolatedClerk(
      keychain: keychain,
      notifier: notifier
    )

    try clerk.storeDeviceToken("local-token")
    clerk.applyResponseClient(
      client(id: "local-client", updatedAt: 100),
      responseSequence: 1,
      serverDate: serverDate
    )
    clerk.applyResponseClient(
      nil,
      responseSequence: 2,
      serverDate: serverDate
    )
    let initialPostCount = notifier.postCount

    let envelope = try makeStore(keychain).save(
      deviceToken: "peer-token",
      client: client(id: "peer-client", updatedAt: 300),
      serverDate: serverDate
    )
    notifier.simulateNotification()

    #expect(clerk.client == envelope.client)
    #expect(clerk.deviceToken == "peer-token")
    #expect(clerk.lastClientServerFetchDate == serverDate)
    #expect(clerk.sharedSessionSyncCoordinator?.requiresClientRefresh == false)
    #expect(notifier.postCount == initialPostCount)
    #expect(try makeStore(keychain).load() == envelope)
  }

  @Test
  func missingDateConflictAppliesLastCompleteWrite() throws {
    let keychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(
      keychain: keychain,
      notifier: notifier
    )
    let localClient = client(id: "local-client", updatedAt: 100)

    try clerk.storeDeviceToken("device-token")
    clerk.applyResponseClient(
      localClient,
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 200)
    )
    let preNotificationGeneration = clerk.clientResponseGeneration
    let initialPostCount = notifier.postCount

    let envelope = try makeStore(keychain).save(
      deviceToken: "device-token",
      client: client(id: "unknown-order-client", updatedAt: 400),
      serverDate: nil
    )
    notifier.simulateNotification()

    #expect(clerk.clientResponseGeneration != preNotificationGeneration)
    #expect(clerk.client == envelope.client)
    #expect(clerk.deviceToken == "device-token")
    #expect(clerk.lastClientServerFetchDate == nil)
    #expect(clerk.sharedSessionSyncCoordinator?.requiresClientRefresh == false)
    #expect(notifier.postCount == initialPostCount)
    #expect(try makeStore(keychain).load() == envelope)

    let didApplyStaleResponse = clerk.applyResponseClient(
      client(id: "stale-response-client", updatedAt: 500),
      responseSequence: 2,
      serverDate: nil,
      clientResponseGeneration: preNotificationGeneration
    )

    #expect(!didApplyStaleResponse)
    #expect(clerk.client == envelope.client)
    #expect(try makeStore(keychain).load() == envelope)
    #expect(notifier.postCount == initialPostCount)
  }

  @Test
  func failedStaleEnvelopeRepairRetriesTheSameRevision() throws {
    let keychain = ControllableSetFailingKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(
      keychain: keychain,
      notifier: notifier
    )
    let localClient = signedInClient(id: "local-client", updatedAt: 300)
    let localServerDate = Date(timeIntervalSince1970: 300)

    try clerk.storeDeviceToken("local-token")
    clerk.applyResponseClient(
      localClient,
      responseSequence: 1,
      serverDate: localServerDate
    )
    let initialPostCount = notifier.postCount
    let staleEnvelope = try makeStore(keychain).save(
      deviceToken: "stale-token",
      client: signedInClient(id: "stale-client", updatedAt: 100),
      serverDate: Date(timeIntervalSince1970: 100)
    )

    keychain.setShouldFail(true)
    notifier.simulateNotification()

    #expect(try makeStore(keychain).load() == staleEnvelope)
    #expect(notifier.postCount == initialPostCount)

    keychain.setShouldFail(false)
    notifier.simulateNotification()

    let repairedEnvelope = try #require(try makeStore(keychain).load())
    #expect(repairedEnvelope.revision != staleEnvelope.revision)
    #expect(repairedEnvelope.deviceToken == "local-token")
    #expect(repairedEnvelope.client == localClient)
    #expect(repairedEnvelope.serverDate == localServerDate)
    #expect(notifier.postCount == initialPostCount + 1)
  }

  @Test
  func appLocalCachePersistsClientKeysWhileSharedSyncUsesEnvelope() async throws {
    let keychain = InMemoryKeychain()
    let clerk = Clerk()
    let cacheManager = CacheManager(
      coordinator: clerk,
      keychain: keychain
    )

    cacheManager.saveClient(
      client(id: "delayed-client", updatedAt: 100),
      serverFetchDate: Date(timeIntervalSince1970: 100)
    )
    cacheManager.deleteClient(serverFetchDate: Date(timeIntervalSince1970: 200))
    await cacheManager.shutdownAndDrain()

    #expect(try keychain.data(forKey: ClerkKeychainKey.cachedClient.rawValue) == nil)
    #expect(
      try keychain.string(
        forKey: ClerkKeychainKey.cachedClientServerDate.rawValue
      ) == "200.0"
    )
  }

  @Test
  func magicLinkStateUsesAppLocalKeychain() throws {
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain
    )

    try dependencies.magicLinkStore.save(
      kind: .signIn,
      flowId: "flow_1",
      codeVerifier: "verifier"
    )

    #expect(
      try appLocalKeychain.hasItem(
        forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue
      )
    )
    #expect(
      try sharedKeychain.hasItem(
        forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue
      ) == false
    )
  }

  @Test
  func watchSyncMetadataUsesAppLocalKeychain() throws {
    configureClerkForTesting()
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain
    )

    let coordinator = WatchConnectivityCoordinator()
    try coordinator.handle(
      .deviceTokenDidChange(previous: nil, current: "device-token"),
      from: clerk
    )

    #expect(
      try appLocalKeychain.string(
        forKey: ClerkKeychainKey.watchSyncDeviceTokenState.rawValue
      ) == "set"
    )
    #expect(
      try sharedKeychain.string(
        forKey: ClerkKeychainKey.watchSyncDeviceTokenState.rawValue
      ) == nil
    )

    try coordinator.handle(
      .deviceTokenDidChange(previous: "device-token", current: nil),
      from: clerk
    )

    #expect(
      try appLocalKeychain.string(
        forKey: ClerkKeychainKey.watchSyncDeviceTokenState.rawValue
      ) == "cleared"
    )
  }

  @Test
  func nonAuthoritativeWatchClearMetadataUsesAppLocalKeychain() throws {
    configureClerkForTesting()
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let clerk = Clerk()
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain
    )
    let payload = WatchSyncPayload(
      deviceTokenUpdate: .notIncluded,
      clientUpdate: .cleared(
        serverFetchDate: Date(timeIntervalSince1970: 200),
        version: WatchSyncVersion(rawValue: 3)
      ),
      environment: nil
    )

    WatchConnectivityCoordinator().apply(payload, from: .watch, to: clerk)

    #expect(
      try appLocalKeychain.string(
        forKey: ClerkKeychainKey.watchSyncAuthState.rawValue
      ) == "cleared"
    )
    #expect(
      try appLocalKeychain.string(
        forKey: ClerkKeychainKey.watchSyncAuthVersion.rawValue
      ) == "3"
    )
    #expect(
      try sharedKeychain.string(
        forKey: ClerkKeychainKey.watchSyncAuthState.rawValue
      ) == nil
    )
    #expect(
      try sharedKeychain.string(
        forKey: ClerkKeychainKey.watchSyncAuthVersion.rawValue
      ) == nil
    )
  }

  @Test
  func phonePayloadPublishesOneCompleteSharedEnvelope() throws {
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(
      keychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain,
      notifier: notifier
    )
    let localClient = signedInClient(id: "local-client", updatedAt: 100)
    let phoneClient = signedInClient(id: "phone-client", updatedAt: 200)
    let phoneServerDate = Date(timeIntervalSince1970: 200)

    try clerk.storeDeviceToken("local-token")
    clerk.applyResponseClient(
      localClient,
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let initialPostCount = notifier.postCount

    let payload = WatchSyncPayload(
      deviceTokenUpdate: .tokenSet(
        token: "phone-token",
        version: WatchSyncVersion(rawValue: 1)
      ),
      clientUpdate: .snapshot(
        client: phoneClient,
        serverFetchDate: phoneServerDate,
        version: WatchSyncVersion(rawValue: 1)
      ),
      environment: nil
    )
    WatchConnectivityCoordinator().apply(payload, from: .phone, to: clerk)

    #expect(notifier.postCount == initialPostCount + 1)
    let envelope = try #require(try makeStore(sharedKeychain).load())
    #expect(envelope.deviceToken == "phone-token")
    #expect(envelope.client == phoneClient)
    #expect(envelope.serverDate == phoneServerDate)
  }

  @Test
  func failedWatchDeviceTokenPersistenceDoesNotApplyPairedClient() throws {
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let identityKeychain = ControllableSetFailingKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(
      keychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain,
      notifier: notifier,
      identityKeychain: identityKeychain
    )
    let localClient = signedInClient(id: "local-client", updatedAt: 100)
    let localServerDate = Date(timeIntervalSince1970: 100)
    let phoneClient = signedInClient(id: "phone-client", updatedAt: 200)

    try clerk.storeDeviceToken("local-token")
    clerk.applyResponseClient(
      localClient,
      responseSequence: 1,
      serverDate: localServerDate
    )
    let initialEnvelope = try #require(try makeStore(sharedKeychain).load())
    let initialPostCount = notifier.postCount

    identityKeychain.setShouldFail(true)
    WatchConnectivityCoordinator().apply(
      WatchSyncPayload(
        deviceTokenUpdate: .tokenSet(
          token: "phone-token",
          version: WatchSyncVersion(rawValue: 1)
        ),
        clientUpdate: .snapshot(
          client: phoneClient,
          serverFetchDate: Date(timeIntervalSince1970: 200),
          version: WatchSyncVersion(rawValue: 1)
        ),
        environment: nil
      ),
      from: .phone,
      to: clerk
    )

    #expect(clerk.deviceToken == "local-token")
    #expect(clerk.client == localClient)
    #expect(clerk.lastClientServerFetchDate == localServerDate)
    #expect(try makeStore(sharedKeychain).load() == initialEnvelope)
    #expect(notifier.postCount == initialPostCount)
  }

  @Test
  func rejectedWatchTokenOnlyBlocksPairedClientWhenTokenDiffers() throws {
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(
      keychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain,
      notifier: notifier
    )
    let localClient = signedInClient(id: "local-client", updatedAt: 100)
    let matchingTokenClient = signedInClient(id: "matching-token-client", updatedAt: 200)
    let differentTokenClient = signedInClient(id: "different-token-client", updatedAt: 300)

    try clerk.storeDeviceToken("local-token")
    clerk.applyResponseClient(
      localClient,
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    try appLocalKeychain.set(
      "3",
      forKey: ClerkKeychainKey.watchSyncDeviceTokenVersion.rawValue
    )
    try appLocalKeychain.set(
      "1",
      forKey: ClerkKeychainKey.watchSyncAuthVersion.rawValue
    )
    let initialPostCount = notifier.postCount
    let watchCoordinator = WatchConnectivityCoordinator()

    watchCoordinator.apply(
      WatchSyncPayload(
        deviceTokenUpdate: .tokenSet(
          token: "local-token",
          version: WatchSyncVersion(rawValue: 2)
        ),
        clientUpdate: .snapshot(
          client: matchingTokenClient,
          serverFetchDate: Date(timeIntervalSince1970: 200),
          version: WatchSyncVersion(rawValue: 2)
        ),
        environment: nil
      ),
      from: .phone,
      to: clerk
    )

    #expect(clerk.deviceToken == "local-token")
    #expect(clerk.client == matchingTokenClient)
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 200))
    let matchingEnvelope = try #require(try makeStore(sharedKeychain).load())
    #expect(matchingEnvelope.deviceToken == "local-token")
    #expect(matchingEnvelope.client == matchingTokenClient)
    #expect(notifier.postCount == initialPostCount + 1)

    watchCoordinator.apply(
      WatchSyncPayload(
        deviceTokenUpdate: .tokenSet(
          token: "different-token",
          version: WatchSyncVersion(rawValue: 2)
        ),
        clientUpdate: .snapshot(
          client: differentTokenClient,
          serverFetchDate: Date(timeIntervalSince1970: 300),
          version: WatchSyncVersion(rawValue: 3)
        ),
        environment: nil
      ),
      from: .phone,
      to: clerk
    )

    #expect(clerk.deviceToken == "local-token")
    #expect(clerk.client == matchingTokenClient)
    #expect(clerk.lastClientServerFetchDate == Date(timeIntervalSince1970: 200))
    #expect(try makeStore(sharedKeychain).load() == matchingEnvelope)
    #expect(notifier.postCount == initialPostCount + 1)
  }

  @Test
  func dateLessAuthoritativeWatchClearRemovesInheritedServerDate() async throws {
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(
      keychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain,
      notifier: notifier
    )
    let localClient = signedInClient(id: "local-client", updatedAt: 100)
    let cacheManager = CacheManager(coordinator: clerk, keychain: appLocalKeychain)
    clerk.cacheManager = cacheManager

    try clerk.storeDeviceToken("device-token")
    clerk.applyResponseClient(
      localClient,
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 300)
    )

    WatchConnectivityCoordinator().apply(
      WatchSyncPayload(
        deviceTokenUpdate: .notIncluded,
        clientUpdate: .cleared(
          serverFetchDate: nil,
          version: WatchSyncVersion(rawValue: 1)
        ),
        environment: nil
      ),
      from: .phone,
      to: clerk
    )
    await cacheManager.shutdownAndDrain()

    #expect(clerk.client == nil)
    #expect(clerk.lastClientServerFetchDate == nil)
    #expect(
      try appLocalKeychain.data(
        forKey: ClerkKeychainKey.cachedClientServerDate.rawValue
      ) == nil
    )
    let envelope = try #require(try makeStore(sharedKeychain).load())
    #expect(envelope.deviceToken == "device-token")
    #expect(envelope.client == nil)
    #expect(envelope.serverDate == nil)
  }

  @Test
  func failedWatchEnvelopePersistenceRetriesOnForeground() throws {
    let sharedKeychain = ControllableSetFailingKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let notifier = TestSharedSessionSyncNotifier()
    let clerk = makeIsolatedClerk(
      keychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain,
      notifier: notifier
    )
    let localClient = signedInClient(id: "local-client", updatedAt: 100)
    let phoneClient = signedInClient(id: "phone-client", updatedAt: 200)
    let phoneServerDate = Date(timeIntervalSince1970: 200)

    try clerk.storeDeviceToken("local-token")
    clerk.applyResponseClient(
      localClient,
      responseSequence: 1,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let initialEnvelope = try #require(try makeStore(sharedKeychain).load())
    let initialPostCount = notifier.postCount

    sharedKeychain.setShouldFail(true)
    WatchConnectivityCoordinator().apply(
      WatchSyncPayload(
        deviceTokenUpdate: .tokenSet(
          token: "phone-token",
          version: WatchSyncVersion(rawValue: 1)
        ),
        clientUpdate: .snapshot(
          client: phoneClient,
          serverFetchDate: phoneServerDate,
          version: WatchSyncVersion(rawValue: 1)
        ),
        environment: nil
      ),
      from: .phone,
      to: clerk
    )

    #expect(clerk.deviceToken == "phone-token")
    #expect(clerk.client == phoneClient)
    #expect(try makeStore(sharedKeychain).load() == initialEnvelope)
    #expect(notifier.postCount == initialPostCount)

    sharedKeychain.setShouldFail(false)
    clerk.emitInternalStateChange(.applicationDidEnterForeground)

    let retriedEnvelope = try #require(try makeStore(sharedKeychain).load())
    #expect(retriedEnvelope.deviceToken == "phone-token")
    #expect(retriedEnvelope.client == phoneClient)
    #expect(retriedEnvelope.serverDate == phoneServerDate)
    #expect(notifier.postCount == initialPostCount + 1)
  }

  @Test
  func publicReloadRequiresSharedSync() async {
    let clerk = Clerk()

    #expect(await clerk.reloadFromSharedStorage() == false)
  }

  @Test
  func notificationNameIncludesInstanceNamespace() {
    let config = Clerk.Options.KeychainConfig(
      service: "com.example.clerk",
      accessGroup: "TEAMID.com.example.clerk"
    )
    let firstNamespace = SharedSessionSyncNamespace(
      frontendApiUrl: "https://first.clerk.accounts.dev"
    )
    let secondNamespace = SharedSessionSyncNamespace(
      frontendApiUrl: "https://second.clerk.accounts.dev"
    )

    let firstName = SharedSessionSyncDarwinNotifier.notificationName(
      for: config,
      namespace: firstNamespace
    )

    #expect(
      firstName == SharedSessionSyncDarwinNotifier.notificationName(
        for: config,
        namespace: firstNamespace
      )
    )
    #expect(
      firstName != SharedSessionSyncDarwinNotifier.notificationName(
        for: config,
        namespace: secondNamespace
      )
    )
    #expect(firstName.contains("TEAMID.com.example.clerk") == false)
  }

  private func makeIsolatedClerk(
    keychain: any KeychainStorage,
    appLocalKeychain: InMemoryKeychain? = nil,
    notifier: TestSharedSessionSyncNotifier,
    clientService: (any ClientServiceProtocol)? = nil,
    identityKeychain: (any KeychainStorage)? = nil
  ) -> Clerk {
    configureClerkForTesting()

    let clerk = Clerk()
    let appLocalKeychain = appLocalKeychain ?? InMemoryKeychain()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      appLocalKeychain: appLocalKeychain,
      identityKeychain: identityKeychain,
      clientService: clientService ?? MockClientService(get: { nil })
    )
    try! dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(
          service: "test.service",
          accessGroup: "test.group"
        ),
        sharedSessionSync: .enabled
      )
    )
    clerk.dependencies = dependencies

    let coordinator = SharedSessionSyncCoordinator(
      keychainConfig: dependencies.configurationManager.options.keychainConfig,
      namespace: namespace,
      clerk: clerk,
      keychain: keychain,
      identityKeychain: dependencies.identityKeychain,
      notifier: notifier
    )
    clerk.sharedSessionSyncCoordinator = coordinator
    clerk.internalStateChanges.addObserver(coordinator)
    return clerk
  }

  private func makeStaleStartupState(
    notifier: TestSharedSessionSyncNotifier
  ) throws -> (
    clerk: Clerk,
    coordinator: SharedSessionSyncCoordinator,
    sharedKeychain: InMemoryKeychain,
    sharedEnvelope: SharedSessionSyncEnvelope,
    localClient: Client
  ) {
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let clerk = Clerk()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain,
      identityKeychain: appLocalKeychain,
      clientService: MockClientService(get: { nil })
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(
          service: "test.service",
          accessGroup: "test.group"
        ),
        sharedSessionSync: .enabled
      )
    )
    clerk.dependencies = dependencies

    let localClient = client(id: "local-client", updatedAt: 300)
    try appLocalKeychain.set(
      "local-token",
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )
    clerk.lastClientServerFetchDate = Date(timeIntervalSince1970: 300)
    clerk.client = localClient

    let sharedEnvelope = try makeStore(sharedKeychain).save(
      deviceToken: "shared-token",
      client: client(id: "shared-client", updatedAt: 100),
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let coordinator = SharedSessionSyncCoordinator(
      keychainConfig: dependencies.configurationManager.options.keychainConfig,
      namespace: namespace,
      clerk: clerk,
      keychain: sharedKeychain,
      identityKeychain: appLocalKeychain,
      notifier: notifier
    )
    clerk.sharedSessionSyncCoordinator = coordinator
    clerk.internalStateChanges.addObserver(coordinator)

    return (
      clerk,
      coordinator,
      sharedKeychain,
      sharedEnvelope,
      localClient
    )
  }

  private func makePersistenceDependencies(
    clerk: Clerk,
    sharedKeychain: InMemoryKeychain,
    appLocalKeychain: InMemoryKeychain,
    syncEnabled: Bool,
    refreshedClient: Client
  ) throws -> MockDependencyContainer {
    let identityKeychain = try SharedSessionSyncAdoption.identityKeychain(
      shared: sharedKeychain,
      appLocal: appLocalKeychain,
      syncEnabled: syncEnabled
    )
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain,
      identityKeychain: identityKeychain,
      clientService: MockClientService(get: { refreshedClient })
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(
          service: "test.shared.service",
          accessGroup: "test.shared.group"
        ),
        sharedSessionSync: syncEnabled ? .enabled : nil
      )
    )
    if syncEnabled {
      try Clerk.prepareSharedSessionAdoptionIfNeeded(
        dependencies: dependencies
      )
    }
    return dependencies
  }

  private func seedCache(
    _ keychain: any KeychainStorage,
    deviceToken: String,
    client: Client,
    serverDate: Date,
    environment: Clerk.Environment
  ) throws {
    try keychain.set(
      deviceToken,
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )
    try keychain.set(
      JSONEncoder.clerkEncoder.encode(client),
      forKey: ClerkKeychainKey.cachedClient.rawValue
    )
    try keychain.set(
      String(serverDate.timeIntervalSince1970),
      forKey: ClerkKeychainKey.cachedClientServerDate.rawValue
    )
    try keychain.set(
      JSONEncoder.clerkEncoder.encode(environment),
      forKey: ClerkKeychainKey.cachedEnvironment.rawValue
    )
  }

  private var namespace: SharedSessionSyncNamespace {
    SharedSessionSyncNamespace(frontendApiUrl: mockBaseUrl.absoluteString)
  }

  private func makeStore(_ keychain: any KeychainStorage) -> SharedSessionSyncStore {
    SharedSessionSyncStore(keychain: keychain, namespace: namespace)
  }

  private func client(id: String, updatedAt: TimeInterval) -> Client {
    var client = Client.mockSignedOut
    client.id = id
    client.updatedAt = Date(timeIntervalSince1970: updatedAt)
    return client
  }

  private func signedInClient(id: String, updatedAt: TimeInterval) -> Client {
    let mock = Client.mock
    var client = (try? JSONDecoder.clerkDecoder.decode(
      Client.self,
      from: JSONEncoder.clerkEncoder.encode(mock)
    )) ?? mock
    client.id = id
    client.updatedAt = Date(timeIntervalSince1970: updatedAt)
    return client
  }

  private func waitUntil(
    timeout: Duration = .milliseconds(500),
    condition: @MainActor () -> Bool
  ) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
      if condition() {
        return
      }
      try await Task.sleep(for: .milliseconds(10))
    }

    #expect(condition())
  }
}

private enum SharedSessionSyncTestError: Error {
  case keychainFailed
  case refreshFailed
}

private final class TestClientResponseService: ClientServiceProtocol {
  private let response: ClientServiceResponse

  init(response: ClientServiceResponse) {
    self.response = response
  }

  @MainActor
  func getResponse(skipClientId _: Bool = false) async throws -> ClientServiceResponse {
    response
  }
}

@MainActor
private final class SequencedClientResponseService: ClientServiceProtocol {
  private var results: [Result<ClientServiceResponse, SharedSessionSyncTestError>]
  private(set) var callCount = 0

  init(results: [Result<ClientServiceResponse, SharedSessionSyncTestError>]) {
    self.results = results
  }

  func getResponse(skipClientId _: Bool = false) async throws -> ClientServiceResponse {
    callCount += 1
    precondition(!results.isEmpty, "Missing test client response")
    return try results.removeFirst().get()
  }
}

@MainActor
private final class SuspendedClientResponseService: ClientServiceProtocol {
  private let response: ClientServiceResponse
  private var continuation: CheckedContinuation<ClientServiceResponse, Never>?

  var isWaiting: Bool {
    continuation != nil
  }

  init(response: ClientServiceResponse) {
    self.response = response
  }

  func getResponse(skipClientId _: Bool = false) async throws -> ClientServiceResponse {
    await withCheckedContinuation { continuation in
      self.continuation = continuation
    }
  }

  func resume() {
    continuation?.resume(returning: response)
    continuation = nil
  }
}

private final class ControllableSetFailingKeychain: @unchecked Sendable, KeychainStorage {
  enum Failure: Error {
    case set
  }

  private let keychain = InMemoryKeychain()
  private let lock = NSLock()
  private var shouldFail = false

  func setShouldFail(_ shouldFail: Bool) {
    lock.lock()
    self.shouldFail = shouldFail
    lock.unlock()
  }

  func set(_ data: Data, forKey key: String) throws {
    lock.lock()
    let shouldFail = shouldFail
    lock.unlock()

    if shouldFail {
      throw Failure.set
    }
    try keychain.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    try keychain.data(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    try keychain.deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try keychain.hasItem(forKey: key)
  }
}

private final class ReadFailingKeychain: @unchecked Sendable, KeychainStorage {
  private let keychain = InMemoryKeychain()
  private var remainingReadFailures: Int

  init(deviceToken: String, failureCount: Int = 1) throws {
    remainingReadFailures = failureCount
    try keychain.set(
      deviceToken,
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )
  }

  func set(_ data: Data, forKey key: String) throws {
    try keychain.set(data, forKey: key)
  }

  func data(forKey key: String) throws -> Data? {
    if remainingReadFailures > 0 {
      remainingReadFailures -= 1
      throw SharedSessionSyncTestError.keychainFailed
    }

    return try keychain.data(forKey: key)
  }

  func deleteItem(forKey key: String) throws {
    try keychain.deleteItem(forKey: key)
  }

  func hasItem(forKey key: String) throws -> Bool {
    try keychain.hasItem(forKey: key)
  }
}

private struct FailingKeychain: KeychainStorage {
  func set(_: Data, forKey _: String) throws {
    throw SharedSessionSyncTestError.keychainFailed
  }

  func data(forKey _: String) throws -> Data? {
    throw SharedSessionSyncTestError.keychainFailed
  }

  func deleteItem(forKey _: String) throws {
    throw SharedSessionSyncTestError.keychainFailed
  }

  func hasItem(forKey _: String) throws -> Bool {
    throw SharedSessionSyncTestError.keychainFailed
  }
}

@MainActor
private final class TestSharedSessionSyncNotifier: SharedSessionSyncNotifying {
  private var handler: (@MainActor () -> Void)?
  var postCount = 0

  func setHandler(_ handler: @escaping @MainActor () -> Void) {
    self.handler = handler
  }

  func post() {
    postCount += 1
  }

  func simulateNotification() {
    handler?()
  }
}
