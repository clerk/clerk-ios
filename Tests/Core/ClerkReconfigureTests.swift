@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Observation
import Testing

@MainActor
@Suite(
  .serialized,
  .enabled(
    if: ProcessInfo.processInfo.environment["CLERK_RUN_RECONFIGURE_TESTS"] == "1",
    "Run with CLERK_RUN_RECONFIGURE_TESTS=1 swift test --no-parallel --filter ClerkReconfigureTests"
  )
)
struct ClerkReconfigureTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func reconfigureUpdatesConfiguration() async throws {
    let original = Clerk.shared
    let publishableKey = publishableKey(for: "ca.clerk.example.com")
    let options = Clerk.Options(
      logLevel: .debug,
      telemetryEnabled: false,
      proxyUrl: "https://proxy.example.com/__clerk"
    )

    let reconfigured = try await Clerk.reconfigure(publishableKey: publishableKey, options: options)
    defer { reconfigured.cleanupManagers() }

    #expect(reconfigured === original)
    #expect(Clerk.shared === original)
    #expect(reconfigured.publishableKey == publishableKey)
    #expect(reconfigured.frontendApiUrl == "https://ca.clerk.example.com")
    #expect(reconfigured.proxyUrl?.absoluteString == "https://proxy.example.com/__clerk")
    #expect(reconfigured.options.logLevel == .debug)
    #expect(reconfigured.options.telemetryEnabled == false)
    #expect(reconfigured.instanceType == .development)
  }

  @Test
  func reconfigureUpdatesInstanceTypeForLiveKey() async throws {
    let publishableKey = publishableKey(for: "live.clerk.example.com", live: true)

    let reconfigured = try await Clerk.reconfigure(publishableKey: publishableKey)
    defer { reconfigured.cleanupManagers() }

    #expect(reconfigured.publishableKey == publishableKey)
    #expect(reconfigured.frontendApiUrl == "https://live.clerk.example.com")
    #expect(reconfigured.instanceType == .production)
  }

  @Test
  func reconfigureNotifiesObserversOfConfigurationValues() async throws {
    let clerk = Clerk.shared
    let didChange = LockIsolated(false)
    withObservationTracking {
      _ = clerk.publishableKey
    } onChange: {
      didChange.setValue(true)
    }

    let reconfigured = try await Clerk.reconfigure(publishableKey: publishableKey(for: "ca.clerk.example.com"))
    defer { reconfigured.cleanupManagers() }

    #expect(didChange.value)
  }

  @Test
  func reconfigureFlushesTheOutgoingTelemetryCollector() async throws {
    let outgoingTelemetry = TelemetryFlushSpy()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      telemetryCollector: outgoingTelemetry
    )

    let reconfigured = try await Clerk.reconfigure(
      publishableKey: publishableKey(for: "telemetry-flush.clerk.example.com"),
      options: .init(telemetryEnabled: false)
    )
    defer { reconfigured.cleanupManagers() }

    let deadline = ContinuousClock.now + .seconds(2)
    while await outgoingTelemetry.completedFlushCount == 0, ContinuousClock.now < deadline {
      try await Task.sleep(for: .milliseconds(20))
    }

    #expect(await outgoingTelemetry.flushCount == 1)
    #expect(await outgoingTelemetry.completedFlushCount == 1)
  }

  enum ShutdownOperation: CaseIterable {
    case reconfigure
    case resetSharedInstance
  }

  @Test(arguments: ShutdownOperation.allCases)
  func shutdownCancelsInFlightPollingTokenRequest(operation: ShutdownOperation) async throws {
    await SessionTokenFetcher.shared.reset()
    let clerk = Clerk.shared
    let requestStarted = LockIsolated(false)
    let requestCancelled = LockIsolated(false)
    let shutdownFinished = LockIsolated(false)
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      clientService: MockClientService(get: { throw CancellationError() }),
      sessionService: MockSessionService(fetchToken: { _, _, _ in
        requestStarted.setValue(true)
        defer { requestCancelled.setValue(Task.isCancelled) }
        try await Task.sleep(for: .seconds(30))
        return nil
      })
    )

    var shutdownTask: Task<Void, Error>?
    let result: Result<Void, Error>
    do {
      clerk.performConfiguration(dependencies: dependencies)
      try clerk.seedIdentity(deviceToken: "polling-token", client: .mock)
      try await waitUntil(timeout: .seconds(2)) { requestStarted.value }

      let task = Task { @MainActor in
        defer { shutdownFinished.setValue(true) }
        switch operation {
        case .reconfigure:
          try await Clerk.reconfigure(
            publishableKey: testPublishableKey,
            options: .init(
              telemetryEnabled: false,
              keychainConfig: .init(service: "com.clerk.tests.polling-shutdown.\(UUID().uuidString)")
            )
          )
        case .resetSharedInstance:
          await Clerk.resetSharedInstanceForTesting()
        }
      }
      shutdownTask = task
      try await waitUntil(timeout: .seconds(2)) { shutdownFinished.value }
      try await task.value
      #expect(requestCancelled.value)
      result = .success(())
    } catch {
      result = .failure(error)
    }

    clerk.cleanupManagers()
    await SessionTokenFetcher.shared.reset()
    _ = await shutdownTask?.result
    clerk.cleanupManagers()
    try result.get()
  }

  @Test
  func reconfigurePreservesRegisteredAuthFlow() async throws {
    Clerk.shared.client = nil
    var registration = Clerk.shared.registerAuthFlow()
    let owner = try #require(registration)

    let reconfigured = try await Clerk.reconfigure(
      publishableKey: publishableKey(for: "registered-auth-flow.clerk.example.com")
    )
    defer { reconfigured.cleanupManagers() }

    var signIn = SignIn.mock
    signIn.status = .complete
    signIn.createdSessionId = Client.mock.currentSession?.id
    reconfigured.applyResponseClient(.mock, completedAuthFlow: .signIn(signIn))

    #expect(reconfigured.isAuthFlowComplete == false)
    let snapshot = try #require(reconfigured.authFlowSnapshot(for: owner))
    guard case .awaiting(_, let completion) = snapshot.phase else {
      Issue.record("Expected the accepted sign-in to await post-auth work")
      return
    }
    #expect(completion?.flowId == signIn.id)

    reconfigured.resetAuthFlow(for: owner)

    #expect(reconfigured.isAuthFlowComplete)

    registration = nil
    await Task.yield()
  }

  @Test
  func invalidReconfigureLeavesCurrentInstanceUntouched() async throws {
    let original = Clerk.shared
    let originalDependencies = Clerk.shared.dependencies
    let originalClient = Client.mock
    let originalEnvironment = Clerk.Environment.mock
    try Clerk.shared.seedIdentity(deviceToken: "old-device-token", client: originalClient)
    Clerk.shared.environment = originalEnvironment

    do {
      _ = try await Clerk.reconfigure(publishableKey: "invalid_key")
      Issue.record("Expected reconfigure to throw for an invalid publishable key")
    } catch let error as ClerkInitializationError {
      if case .invalidPublishableKeyFormat = error {
      } else {
        Issue.record("Expected invalidPublishableKeyFormat, got \(error)")
      }
    } catch {
      Issue.record("Expected ClerkInitializationError, got \(error)")
    }

    let dependenciesUnchanged = Clerk.shared.dependencies === originalDependencies
    #expect(Clerk.shared === original)
    #expect(dependenciesUnchanged)
    #expect(Clerk.shared.identityController.currentDeviceToken == "old-device-token")
    #expect(try Clerk.shared.dependencies.identityStore.load()?.deviceToken == "old-device-token")
    #expect(Clerk.shared.client?.id == originalClient.id)
    #expect(Clerk.shared.session?.id == originalClient.currentSession?.id)
    #expect(Clerk.shared.environment == originalEnvironment)
  }

  @Test
  func reconfigureClearsLocalStateAndStorage() async throws {
    let oldKeychain = InMemoryKeychain()
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: oldKeychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )
    try Clerk.shared.seedIdentity(deviceToken: "old-device-token", client: .mock)
    try oldKeychain.set("old-client", forKey: ClerkKeychainKey.cachedClient.rawValue)

    let targetService = "com.clerk.tests.reconfigure.\(UUID().uuidString)"
    let targetKeychain = SystemKeychain(service: targetService)
    try targetKeychain.set("target-environment", forKey: ClerkKeychainKey.cachedEnvironment.rawValue)
    defer {
      for key in ClerkKeychainKey.allCases {
        try? targetKeychain.deleteItem(forKey: key.rawValue)
      }
    }

    Clerk.shared.client = .mock
    Clerk.shared.environment = .mock
    Clerk.shared.sessionsByUserId = [User.mock.id: [.mock]]
    SessionTemplateTokensCache.shared.insertToken(.init(jwt: "jwt_123"), cacheKey: "session-token")

    let options = Clerk.Options(keychainConfig: .init(service: targetService))
    let reconfigured = try await Clerk.reconfigure(
      publishableKey: publishableKey(for: "runtime-clear.clerk.example.com"),
      options: options
    )
    defer { reconfigured.cleanupManagers() }

    #expect(reconfigured.client == nil)
    #expect(reconfigured.environment == nil)
    #expect(reconfigured.sessionsByUserId.isEmpty)
    #expect(try oldKeychain.hasItem(forKey: ClerkKeychainKey.cachedClient.rawValue) == false)
    #expect(try oldKeychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == false)
    #expect(try targetKeychain.hasItem(forKey: ClerkKeychainKey.cachedEnvironment.rawValue) == false)
    #expect(SessionTemplateTokensCache.shared.getToken(cacheKey: "session-token") == nil)
  }

  @Test
  func reconfigureWithSameKeychainClearsStorage() async throws {
    let service = "com.clerk.tests.same-keychain.\(UUID().uuidString)"
    let keychain = SystemKeychain(service: service)
    defer {
      for key in ClerkKeychainKey.allCases {
        try? keychain.deleteItem(forKey: key.rawValue)
      }
    }

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: Clerk.shared.runtimeScope),
      keychain: keychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )
    try keychain.set("old-client", forKey: ClerkKeychainKey.cachedClient.rawValue)
    try keychain.set("old-environment", forKey: ClerkKeychainKey.cachedEnvironment.rawValue)

    try Clerk.shared.seedIdentity(deviceToken: "old-device-token", client: .mock)
    Clerk.shared.environment = .mock

    let options = Clerk.Options(keychainConfig: .init(service: service))
    let reconfigured = try await Clerk.reconfigure(
      publishableKey: publishableKey(for: "same-keychain.clerk.example.com"),
      options: options
    )
    defer { reconfigured.cleanupManagers() }

    #expect(reconfigured.client == nil)
    #expect(reconfigured.environment == nil)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == false)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedClient.rawValue) == false)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedEnvironment.rawValue) == false)
  }

  @Test
  func reconfigureLeavesAnIdentitySharedWithOtherApps() async throws {
    let clerk = Clerk.shared
    let sharedKeychain = InMemoryKeychain()
    let sourceDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: sharedKeychain,
      appLocalKeychain: InMemoryKeychain(),
      identityIsInAccessGroup: true,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    clerk.performConfiguration(dependencies: sourceDependencies)
    try clerk.seedIdentity(deviceToken: "shared-token", client: .mock, serverDate: Date(timeIntervalSince1970: 100))
    clerk.environment = .mock
    clerk.sessionsByUserId = [User.mock.id: [.mock]]

    let targetService = "com.clerk.tests.shared-source-target.\(UUID().uuidString)"
    let targetKeychain = SystemKeychain(service: targetService)
    defer {
      for key in ClerkKeychainKey.allCases {
        try? targetKeychain.deleteItem(forKey: key.rawValue)
      }
    }

    let reconfigured = try await Clerk.reconfigure(
      publishableKey: testPublishableKey,
      options: Clerk.Options(keychainConfig: .init(service: targetService))
    )
    defer { reconfigured.cleanupManagers() }

    #expect(try sourceDependencies.identityStore.load()?.deviceToken == "shared-token")
    #expect(reconfigured.client == nil)
    #expect(reconfigured.session == nil)
    #expect(reconfigured.environment == nil)
    #expect(reconfigured.sessionsByUserId.isEmpty)
  }

  @Test
  func unreachableKeychainFailsReconfigureBeforeDestructiveWrites() async throws {
    let original = Clerk.shared
    let identityKeychain = InMemoryKeychain()
    let sourceDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: original.runtimeScope),
      keychain: MissingEntitlementKeychain(),
      appLocalKeychain: identityKeychain,
      identityKeychain: identityKeychain,
      telemetryCollector: original.dependencies.telemetryCollector
    )
    original.performConfiguration(dependencies: sourceDependencies)
    let previousRuntime = original.runtime
    try original.seedIdentity(deviceToken: "source-token", client: .mock)
    defer { original.cleanupManagers() }

    await #expect(throws: KeychainError.self) {
      _ = try await Clerk.reconfigure(publishableKey: testPublishableKey)
    }

    #expect(Clerk.shared === original)
    #expect(original.runtime === previousRuntime)
    #expect(previousRuntime.isCurrent)
    #expect(original.dependencies === sourceDependencies)
    #expect(try sourceDependencies.identityStore.load()?.deviceToken == "source-token")
    #expect(original.client?.id == Client.mock.id)
  }

  @Test
  func failedReconfigureLeavesPreviousRuntimeUntouched() async throws {
    let original = Clerk.shared
    let throwingKeychain = ThrowingDeleteKeychain()
    let previousDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: Clerk.shared.runtimeScope),
      keychain: throwingKeychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )
    original.performConfiguration(dependencies: previousDependencies)
    let previousRuntime = original.runtime
    try original.seedIdentity(deviceToken: "source-token", client: .mock)
    original.environment = .mock
    defer { original.cleanupManagers() }

    let targetService = "com.clerk.tests.failed-reconfigure.\(UUID().uuidString)"
    let targetKeychain = SystemKeychain(service: targetService)
    defer {
      for key in ClerkKeychainKey.allCases {
        try? targetKeychain.deleteItem(forKey: key.rawValue)
      }
    }

    do {
      _ = try await Clerk.reconfigure(
        publishableKey: publishableKey(for: "failed-rollback.clerk.example.com"),
        options: Clerk.Options(keychainConfig: .init(service: targetService))
      )
      Issue.record("Expected reconfigure to throw when old keychain clearing fails")
    } catch {}

    let dependenciesUnchanged = Clerk.shared.dependencies === previousDependencies
    #expect(Clerk.shared === original)
    #expect(Clerk.shared.runtime === previousRuntime)
    #expect(previousRuntime.isCurrent)
    #expect(dependenciesUnchanged)
    #expect(try previousDependencies.identityStore.deviceToken() == "source-token")
    #expect(Clerk.shared.identityController.currentDeviceToken == "source-token")
    #expect(Clerk.shared.client?.id == Client.mock.id)
    #expect(Clerk.shared.environment == .mock)
  }

  @Test(arguments: [ClerkKeychainKey.cachedClient, .cachedEnvironment])
  func failedReconfigureAfterDeletingDeviceTokenSignsOutInMemory(failingKey: ClerkKeychainKey) async throws {
    let original = Clerk.shared
    let previousDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: Clerk.shared.runtimeScope),
      keychain: ThrowingDeleteKeychain(failingKey: failingKey),
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )
    original.performConfiguration(dependencies: previousDependencies)
    try original.seedIdentity(deviceToken: "source-token", client: .mock)
    original.environment = .mock
    defer { original.cleanupManagers() }

    let targetService = "com.clerk.tests.partial-clear.\(UUID().uuidString)"
    let targetKeychain = SystemKeychain(service: targetService)
    defer {
      for key in ClerkKeychainKey.allCases {
        try? targetKeychain.deleteItem(forKey: key.rawValue)
      }
    }

    do {
      _ = try await Clerk.reconfigure(
        publishableKey: publishableKey(for: "partial-clear.clerk.example.com"),
        options: Clerk.Options(keychainConfig: .init(service: targetService))
      )
      Issue.record("Expected reconfigure to throw when a keychain item cannot be deleted")
    } catch {}

    #expect(Clerk.shared.dependencies === previousDependencies)
    #expect(try previousDependencies.identityStore.deviceToken() == nil)
    #expect(Clerk.shared.identityController.currentDeviceToken == nil)
    #expect(Clerk.shared.client == nil)
    #expect(Clerk.shared.environment == .mock)
  }

  @Test
  func keychainClearStartedDuringReconfigurationWaitsForInstalledRuntime() async throws {
    let clerk = Clerk.shared
    let keychain = InMemoryKeychain()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      keychain: keychain,
      telemetryCollector: clerk.dependencies.telemetryCollector
    )
    clerk.performConfiguration(dependencies: dependencies)
    try clerk.seedIdentity(deviceToken: "device-token")
    defer { clerk.cleanupManagers() }

    try Clerk.beginRuntimeReconfiguration()
    var endedReconfiguration = false
    defer {
      if !endedReconfiguration {
        Clerk.endRuntimeReconfiguration()
      }
    }
    let clearTask = Task { @MainActor in try await Clerk.clearAllKeychainItemsAndWait() }
    await Task.yield()

    #expect(clerk.identityController.currentDeviceToken == "device-token")

    Clerk.endRuntimeReconfiguration()
    endedReconfiguration = true
    try await clearTask.value

    #expect(clerk.identityController.currentDeviceToken == nil)
    #expect(try clerk.dependencies.identityStore.load() == nil)
  }

  @Test
  func reconfigureDrainsPendingCacheWritesBeforeClearingOldKeychain() async throws {
    let oldKeychain = SlowKeychain(delay: 0.5)
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: Clerk.shared.runtimeScope),
      keychain: oldKeychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )
    Clerk.shared.performConfiguration(dependencies: dependencies)
    Clerk.shared.client = .mock

    let targetService = "com.clerk.tests.pending-cache-drain.\(UUID().uuidString)"
    let targetKeychain = SystemKeychain(service: targetService)
    defer {
      for key in ClerkKeychainKey.allCases {
        try? targetKeychain.deleteItem(forKey: key.rawValue)
      }
    }

    let reconfigured = try await Clerk.reconfigure(
      publishableKey: publishableKey(for: "pending-cache-drain.clerk.example.com"),
      options: Clerk.Options(keychainConfig: .init(service: targetService))
    )
    defer { reconfigured.cleanupManagers() }

    #expect(try oldKeychain.hasItem(forKey: ClerkKeychainKey.cachedClient.rawValue) == false)
  }

  @Test
  func reconfigureClearsTokensBeforeSessionChangedEvent() async throws {
    let cachedJWT = try unexpiredJWT()
    let sessionService = MockSessionService(fetchToken: { _, _, _ in
      throw CancellationError()
    })
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: Clerk.shared.runtimeScope),
      keychain: InMemoryKeychain(),
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector,
      sessionService: sessionService
    )
    Clerk.shared.performConfiguration(dependencies: dependencies)
    Clerk.shared.client = .mock
    SessionTemplateTokensCache.shared.insertToken(
      .init(jwt: cachedJWT),
      cacheKey: Session.mock.tokenCacheKey(template: "secondary")
    )

    let observedToken = LockIsolated<String?>(nil)
    let observedEventProcessed = LockIsolated(false)
    let stream = Clerk.shared.auth.events
    let eventTask = Task { @MainActor in
      for await event in stream {
        guard case .sessionChanged(let oldValue, nil) = event else {
          continue
        }

        if let oldValue {
          let token = SessionTemplateTokensCache.shared.getToken(cacheKey: oldValue.tokenCacheKey(template: "secondary"))?.jwt
          observedToken.setValue(token)
        }
        observedEventProcessed.setValue(true)
        break
      }
    }
    defer { eventTask.cancel() }

    let reconfigured = try await Clerk.reconfigure(
      publishableKey: publishableKey(for: "token-reset-before-event.clerk.example.com")
    )
    defer { reconfigured.cleanupManagers() }

    try await waitUntil(timeout: .seconds(2)) { observedEventProcessed.value }
    #expect(observedToken.value == nil)
  }

  @Test
  func tokenReadsAreCancelledWhileReconfigureIsInProgress() async throws {
    let cachedJWT = try unexpiredJWT()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: Clerk.shared.runtimeScope),
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )
    Clerk.shared.performConfiguration(dependencies: dependencies)
    Clerk.shared.client = .mock
    let staleSession = try #require(Clerk.shared.session)
    SessionTemplateTokensCache.shared.insertToken(
      .init(jwt: cachedJWT),
      cacheKey: staleSession.tokenCacheKey(template: "secondary")
    )

    try Clerk.beginRuntimeReconfiguration()
    defer { Clerk.endRuntimeReconfiguration() }

    await #expect(throws: CancellationError.self) {
      _ = try await staleSession.getToken()
    }
  }

  @Test
  func modelServiceCallsAreCancelledWhileReconfigureIsInProgress() async throws {
    let serviceCalls = LockIsolated(0)
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: Clerk.shared.runtimeScope),
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector,
      userService: MockUserService(reload: {
        serviceCalls.withValue { $0 += 1 }
        return .mock
      })
    )
    try Clerk.shared.performConfiguration(dependencies: dependencies)

    try Clerk.beginRuntimeReconfiguration()
    defer { Clerk.endRuntimeReconfiguration() }

    await #expect(throws: CancellationError.self) {
      _ = try await User.mock.reload()
    }
    #expect(serviceCalls.value == 0)
  }

  @Test
  func tokenReadBeforeConfigureThrowsConfigurationError() async throws {
    await Clerk.resetSharedInstanceForTesting()
    defer { configureClerkForTesting() }

    do {
      _ = try await Session.mock.getToken()
      Issue.record("Expected token reads before configuration to throw")
    } catch let error as ClerkClientError {
      #expect(error.message == "Clerk must be configured before getting a session token.")
    } catch {
      Issue.record("Expected ClerkClientError, got \(error)")
    }
  }

  @Test
  func reconfigureBeforeConfigureInstallsSharedInstance() async throws {
    await Clerk.resetSharedInstanceForTesting()

    let configured = try await Clerk.reconfigure(
      publishableKey: publishableKey(for: "initial-reconfigure.clerk.example.com")
    )
    defer { configured.cleanupManagers() }

    #expect(Clerk.shared === configured)
    #expect(configured.publishableKey == publishableKey(for: "initial-reconfigure.clerk.example.com"))
  }

  @Test
  func reconfigureBeforeConfigureClearsPersistedCredentials() async throws {
    await Clerk.resetSharedInstanceForTesting()
    defer { configureClerkForTesting() }

    let service = "com.clerk.tests.initial-reconfigure.\(UUID().uuidString)"
    let keychain = SystemKeychain(service: service)
    defer {
      for key in ClerkKeychainKey.allCases {
        try? keychain.deleteItem(forKey: key.rawValue)
      }
    }
    try keychain.set(
      JSONEncoder.clerkEncoder.encode(Client.mock),
      forKey: ClerkKeychainKey.cachedClient.rawValue
    )

    let configured = try await Clerk.reconfigure(
      publishableKey: publishableKey(for: "initial-clear.clerk.example.com"),
      options: .init(keychainConfig: .init(service: service))
    )
    defer { configured.cleanupManagers() }

    #expect(configured.client == nil)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.cachedClient.rawValue) == false)
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == false)
  }

  @Test
  func concurrentReconfigureThrowsWhileFirstReconfigureIsInProgress() async throws {
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: Clerk.shared.runtimeScope),
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )
    Clerk.shared.performConfiguration(dependencies: dependencies)

    try Clerk.beginRuntimeReconfiguration()
    defer { Clerk.endRuntimeReconfiguration() }

    await #expect {
      _ = try await Clerk.reconfigure(publishableKey: publishableKey(for: "second-target.clerk.example.com"))
    } throws: { error in
      (error as? ClerkClientError)?.message?.contains("already reconfiguring") == true
    }
  }

  @Test
  func oldInFlightClientResponseIsIgnoredAfterReconfigure() async throws {
    let oldClientService = Clerk.shared.dependencies.clientService
    let originalURL = URL(string: mockBaseUrl.absoluteString + "/v1/client")!
    var mock = try Mock(
      url: originalURL,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(Client.mock),
      ]
    )
    mock.delay = .milliseconds(100)
    mock.register()

    let oldRequest = Task { @MainActor in
      try await oldClientService.getResponse()
    }
    try await Task.sleep(for: .milliseconds(20))

    let reconfigured = try await Clerk.reconfigure(
      publishableKey: publishableKey(for: "stale-target.clerk.example.com")
    )
    defer { reconfigured.cleanupManagers() }

    do {
      _ = try await oldRequest.value
      Issue.record("Expected old in-flight request to be cancelled after reconfigure")
    } catch is CancellationError {
    } catch {
      Issue.record("Expected CancellationError, got \(error)")
    }

    #expect(Clerk.shared.client == nil)
  }

  @Test
  func staleRefreshClientDoesNotApplyAfterReconfigure() async throws {
    let staleClient = Client(
      id: "stale-refresh-client",
      sessions: [],
      lastActiveSessionId: nil,
      updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let serviceStarted = LockIsolated(false)
    let service = MockClientService(get: {
      serviceStarted.setValue(true)
      try await Task.sleep(for: .milliseconds(100))
      return staleClient
    })
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: Clerk.shared.runtimeScope),
      clientService: service
    )

    let refreshTask = Task { @MainActor in
      try await Clerk.shared.refreshClient()
    }
    try await waitUntil(timeout: .seconds(1)) { serviceStarted.value }

    let reconfigured = try await Clerk.reconfigure(
      publishableKey: publishableKey(for: "stale-refresh-client.clerk.example.com")
    )
    defer { reconfigured.cleanupManagers() }

    do {
      _ = try await refreshTask.value
      Issue.record("Expected stale refreshClient result to be cancelled after reconfigure")
    } catch is CancellationError {
    } catch {
      Issue.record("Expected CancellationError, got \(error)")
    }

    #expect(Clerk.shared.client?.id != staleClient.id)
  }

  @Test
  func staleRefreshEnvironmentDoesNotApplyAfterReconfigure() async throws {
    let serviceStarted = LockIsolated(false)
    let service = MockEnvironmentService(get: {
      serviceStarted.setValue(true)
      try await Task.sleep(for: .milliseconds(100))
      return .mock
    })
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: Clerk.shared.runtimeScope),
      environmentService: service
    )

    let refreshTask = Task { @MainActor in
      try await Clerk.shared.refreshEnvironment()
    }
    try await waitUntil(timeout: .seconds(1)) { serviceStarted.value }

    let reconfigured = try await Clerk.reconfigure(
      publishableKey: publishableKey(for: "stale-refresh-environment.clerk.example.com")
    )
    defer { reconfigured.cleanupManagers() }

    do {
      _ = try await refreshTask.value
      Issue.record("Expected stale refreshEnvironment result to be cancelled after reconfigure")
    } catch is CancellationError {
    } catch {
      Issue.record("Expected CancellationError, got \(error)")
    }

    #expect(Clerk.shared.environment == nil)
  }

  @Test
  func authEventsStreamRemainsUsableAfterReconfigure() async throws {
    Clerk.shared.client = .mock

    let events = LockIsolated<[AuthEvent]>([])
    let stream = Clerk.shared.auth.events
    let eventTask = Task { @MainActor in
      for await event in stream {
        events.withValue { $0.append(event) }
        if events.value.count >= 2 {
          break
        }
      }
    }
    defer { eventTask.cancel() }

    let reconfigured = try await Clerk.reconfigure(
      publishableKey: publishableKey(for: "events-target.clerk.example.com")
    )
    defer { reconfigured.cleanupManagers() }
    reconfigured.client = .mock

    try await waitForEvents(events, count: 2)

    let observedEvents = events.value
    guard observedEvents.count >= 2 else {
      Issue.record("Expected at least two auth events")
      return
    }

    if case .sessionChanged(let oldValue, let newValue) = observedEvents[0] {
      #expect(oldValue?.id == Session.mock.id)
      #expect(newValue == nil)
    } else {
      Issue.record("Expected first event to clear the active session")
    }

    if case .sessionChanged(let oldValue, let newValue) = observedEvents[1] {
      #expect(oldValue == nil)
      #expect(newValue?.id == Session.mock.id)
    } else {
      Issue.record("Expected second event to be delivered after reconfigure")
    }
  }

  private func publishableKey(for host: String, live: Bool = false) -> String {
    let data = Data("\(host)$".utf8)
    let encoded = data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")

    return "\(live ? "pk_live" : "pk_test")_\(encoded)"
  }

  private func unexpiredJWT() throws -> String {
    try [
      base64URLEncodedJSON(["alg": "none", "typ": "JWT"]),
      base64URLEncodedJSON(["exp": Int(Date.now.addingTimeInterval(3600).timeIntervalSince1970)]),
      "signature",
    ].joined(separator: ".")
  }

  private func base64URLEncodedJSON(_ object: [String: Any]) throws -> String {
    try JSONSerialization.data(withJSONObject: object)
      .base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  private func waitForEvents(
    _ events: LockIsolated<[AuthEvent]>,
    count: Int,
    timeout: Duration = .milliseconds(500)
  ) async throws {
    enum TimeoutError: Error {
      case timedOut
    }

    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
      if events.value.count >= count {
        return
      }
      try await Task.sleep(for: .milliseconds(10))
    }

    if events.value.count < count {
      throw TimeoutError.timedOut
    }
  }

  private func waitUntil(
    timeout: Duration = .milliseconds(500),
    _ condition: () -> Bool
  ) async throws {
    enum TimeoutError: Error {
      case timedOut
    }

    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
      if condition() {
        return
      }
      try await Task.sleep(for: .milliseconds(10))
    }

    if !condition() {
      throw TimeoutError.timedOut
    }
  }
}

@MainActor
private final class ReconfigurationClearGate {
  private(set) var isSuspended = false
  private var continuation: CheckedContinuation<Void, Never>?

  func suspend() async {
    isSuspended = true
    await withCheckedContinuation { continuation = $0 }
    isSuspended = false
  }

  func waitUntilSuspended() async throws {
    let deadline = ContinuousClock.now + .seconds(1)
    while ContinuousClock.now < deadline {
      if isSuspended { return }
      await Task.yield()
    }
    throw ClerkClientError(message: "Timed out waiting for Keychain clear.")
  }

  func resume() {
    continuation?.resume()
    continuation = nil
  }
}

private final class SlowKeychain: KeychainStorage, @unchecked Sendable {
  private let delay: TimeInterval
  private let lock = NSLock()
  private var storage: [String: Data] = [:]

  init(delay: TimeInterval) {
    self.delay = delay
  }

  func set(_ data: Data, forKey key: String) throws {
    Thread.sleep(forTimeInterval: delay)
    lock.lock()
    defer { lock.unlock() }
    storage[key] = data
  }

  func data(forKey key: String) throws -> Data? {
    lock.lock()
    defer { lock.unlock() }
    return storage[key]
  }

  func deleteItem(forKey key: String) throws {
    lock.lock()
    defer { lock.unlock() }
    storage[key] = nil
  }

  func hasItem(forKey key: String) throws -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return storage[key] != nil
  }
}

private actor TelemetryFlushSpy: TelemetryCollectorProtocol {
  private(set) var flushCount = 0
  private(set) var completedFlushCount = 0

  func record(_: TelemetryEventRaw) async {}

  func flush() async {
    flushCount += 1
    try? await Task.sleep(for: .milliseconds(50))
    if !Task.isCancelled {
      completedFlushCount += 1
    }
  }
}

private final class ThrowingDeleteKeychain: KeychainStorage, @unchecked Sendable {
  private enum DeleteError: Error {
    case failed
  }

  private let lock = NSLock()
  private var storage: [String: Data] = [:]
  private let failingKey: ClerkKeychainKey?

  init(failingKey: ClerkKeychainKey? = nil) {
    self.failingKey = failingKey
  }

  func set(_ data: Data, forKey key: String) throws {
    lock.lock()
    defer { lock.unlock() }
    storage[key] = data
  }

  func data(forKey key: String) throws -> Data? {
    lock.lock()
    defer { lock.unlock() }
    return storage[key]
  }

  func deleteItem(forKey key: String) throws {
    guard let failingKey, failingKey.rawValue != key else {
      throw DeleteError.failed
    }
    lock.lock()
    defer { lock.unlock() }
    storage[key] = nil
  }

  func hasItem(forKey key: String) throws -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return storage[key] != nil
  }
}
