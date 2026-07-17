@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
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
  func reconfigureUpdatesConfigurationAndPreservesSharedIdentity() async throws {
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
  func invalidReconfigureLeavesCurrentInstanceUntouched() async throws {
    let original = Clerk.shared
    let originalDependencies = Clerk.shared.dependencies
    let keychain = Clerk.shared.dependencies.keychain
    let originalClient = Client.mock
    let originalEnvironment = Clerk.Environment.mock
    try keychain.set("old-device-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    Clerk.shared.client = originalClient
    Clerk.shared.environment = originalEnvironment

    do {
      _ = try await Clerk.reconfigure(publishableKey: "invalid_key")
      Issue.record("Expected reconfigure to throw for an invalid publishable key")
    } catch let error as ClerkInitializationError {
      if case .invalidPublishableKeyFormat = error {
        // Expected.
      } else {
        Issue.record("Expected invalidPublishableKeyFormat, got \(error)")
      }
    } catch {
      Issue.record("Expected ClerkInitializationError, got \(error)")
    }

    let dependenciesUnchanged = Clerk.shared.dependencies === originalDependencies
    #expect(Clerk.shared === original)
    #expect(dependenciesUnchanged)
    #expect(try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == "old-device-token")
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
    try oldKeychain.set("old-device-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
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
    await SessionTokensCache.shared.insertToken(.init(jwt: "jwt_123"), cacheKey: "session-token")

    let options = Clerk.Options(keychainConfig: .init(service: targetService))
    let reconfigured = try await Clerk.reconfigure(
      publishableKey: publishableKey(for: "runtime-clear.clerk.example.com"),
      options: options
    )
    defer { reconfigured.cleanupManagers() }

    #expect(reconfigured.client == nil)
    #expect(reconfigured.environment == nil)
    #expect(reconfigured.sessionsByUserId.isEmpty)
    #expect(try oldKeychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue) == false)
    #expect(try oldKeychain.hasItem(forKey: ClerkKeychainKey.cachedClient.rawValue) == false)
    #expect(try targetKeychain.hasItem(forKey: ClerkKeychainKey.cachedEnvironment.rawValue) == false)
    #expect(await SessionTokensCache.shared.getToken(cacheKey: "session-token") == nil)
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
    try keychain.set("old-device-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try keychain.set("old-client", forKey: ClerkKeychainKey.cachedClient.rawValue)
    try keychain.set("old-environment", forKey: ClerkKeychainKey.cachedEnvironment.rawValue)

    Clerk.shared.client = .mock
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
  func failedReconfigureRestoresPartiallyDeletedOverlappingKeychain() async throws {
    let original = Clerk.shared
    let previousEpoch = Clerk.shared.configurationEpoch
    let throwingKeychain = PartiallyFailingDeleteKeychain(
      successfulDeletesBeforeFailure: 3
    )
    try seedIdentityCache(in: throwingKeychain)
    let previousDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: Clerk.shared.runtimeScope),
      keychain: throwingKeychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )
    try previousDependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init()
    )
    original.performConfiguration(dependencies: previousDependencies)
    defer { original.cleanupManagers() }

    let nextEpoch = original.nextConfigurationEpoch
    let targetDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(
        runtimeScope: .init(epoch: nextEpoch, runtimeState: original.runtimeState)
      ),
      keychain: throwingKeychain,
      telemetryCollector: original.dependencies.telemetryCollector
    )
    try targetDependencies.configurationManager.configure(
      publishableKey: publishableKey(for: "failed-rollback.clerk.example.com"),
      options: .init()
    )

    do {
      _ = try await Clerk.applyReconfiguration(
        to: original,
        dependencies: targetDependencies,
        nextEpoch: nextEpoch
      )
      Issue.record("Expected reconfigure to throw when overlapping keychain clearing fails")
    } catch let error as ClerkClientError {
      #expect(error.message?.contains("Unable to clear Clerk keychain items") == true)
    } catch {
      Issue.record("Expected ClerkClientError, got \(error)")
    }

    let dependenciesUnchanged = Clerk.shared.dependencies === previousDependencies
    #expect(Clerk.shared === original)
    #expect(Clerk.shared.configurationEpoch == previousEpoch)
    #expect(dependenciesUnchanged)
    #expect(Clerk.shared.client?.id == Client.mock.id)
    #expect(Clerk.shared.environment == .mock)

    try expectIdentityCache(in: throwingKeychain)

    let relaunched = Clerk()
    let relaunchedDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: relaunched.runtimeScope),
      keychain: throwingKeychain
    )
    try relaunchedDependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init()
    )
    relaunched.performConfiguration(dependencies: relaunchedDependencies)
    defer { relaunched.cleanupManagers() }

    #expect(relaunched.client?.id == Client.mock.id)
    #expect(relaunched.environment == .mock)
  }

  @Test
  func keychainSnapshotRestoreDoesNotOverwriteNewerSharedEnvelope() throws {
    let keychain = InMemoryKeychain()
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: Clerk.shared.runtimeScope),
      keychain: keychain
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init()
    )
    let store = SharedSessionSyncStore(
      keychain: keychain,
      namespace: SharedSessionSyncNamespace(
        frontendApiUrl: dependencies.configurationManager.frontendApiUrl
      )
    )

    try keychain.set("original-device-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    _ = try store.save(
      deviceToken: "original-shared-token",
      client: nil,
      serverDate: Date(timeIntervalSince1970: 100)
    )
    let snapshot = try Clerk.captureKeychainSnapshot(in: [dependencies])

    try keychain.set("changed-device-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    let newerEnvelope = try store.save(
      deviceToken: "newer-shared-token",
      client: nil,
      serverDate: Date(timeIntervalSince1970: 200)
    )

    try snapshot.restore()

    #expect(
      try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
        == "original-device-token"
    )
    #expect(try store.load()?.revision == newerEnvelope.revision)
  }

  @Test
  func failedAdoptionRestoresPreviousAndTargetKeychains() async throws {
    let original = Clerk.shared
    let previousEpoch = original.configurationEpoch
    let previousKeychain = InMemoryKeychain()
    try seedIdentityCache(in: previousKeychain)
    let previousDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: original.runtimeScope),
      keychain: previousKeychain,
      telemetryCollector: original.dependencies.telemetryCollector
    )
    try previousDependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init()
    )
    original.performConfiguration(dependencies: previousDependencies)
    defer { original.cleanupManagers() }

    let targetSharedKeychain = InMemoryKeychain()
    let targetAppLocalKeychain = InMemoryKeychain()
    let targetIdentityKeychain = AdoptionMarkerFailingKeychain()
    try seedIdentityCache(in: targetSharedKeychain)
    try targetAppLocalKeychain.set(
      "pending-flow",
      forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue
    )
    try targetIdentityKeychain.set(
      "existing-attest-key",
      forKey: ClerkKeychainKey.attestKeyId.rawValue
    )
    let targetSharedState = try keychainContents(in: targetSharedKeychain)
    let targetAppLocalState = try keychainContents(in: targetAppLocalKeychain)
    let targetIdentityState = try keychainContents(in: targetIdentityKeychain)

    let nextEpoch = original.nextConfigurationEpoch
    let targetDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(
        runtimeScope: .init(epoch: nextEpoch, runtimeState: original.runtimeState)
      ),
      keychain: targetSharedKeychain,
      appLocalKeychain: targetAppLocalKeychain,
      identityKeychain: targetIdentityKeychain,
      telemetryCollector: original.dependencies.telemetryCollector
    )
    try targetDependencies.configurationManager.configure(
      publishableKey: publishableKey(for: "failed-adoption.clerk.example.com"),
      options: .init(
        keychainConfig: .init(
          service: "test.shared.service",
          accessGroup: "test.shared.group"
        ),
        sharedSessionSync: .enabled
      )
    )

    do {
      _ = try await Clerk.applyReconfiguration(
        to: original,
        dependencies: targetDependencies,
        nextEpoch: nextEpoch
      )
      Issue.record("Expected shared-session adoption to fail")
    } catch is AdoptionMarkerFailingKeychain.WriteError {
      // Expected.
    } catch {
      Issue.record("Expected adoption marker write error, got \(error)")
    }

    #expect(Clerk.shared === original)
    #expect(original.configurationEpoch == previousEpoch)
    #expect(original.dependencies === previousDependencies)
    #expect(original.client?.id == Client.mock.id)
    #expect(original.environment == .mock)
    #expect(try keychainContents(in: targetSharedKeychain) == targetSharedState)
    #expect(try keychainContents(in: targetAppLocalKeychain) == targetAppLocalState)
    #expect(try keychainContents(in: targetIdentityKeychain) == targetIdentityState)

    try expectIdentityCache(in: previousKeychain)
  }

  @Test
  func failedAdoptionSnapshotRestoreRemovesPartiallyCopiedIdentity() throws {
    let sharedKeychain = InMemoryKeychain()
    let appLocalKeychain = InMemoryKeychain()
    let identityKeychain = AdoptionMarkerFailingKeychain()
    try seedIdentityCache(in: sharedKeychain)
    try appLocalKeychain.set(
      "pending-flow",
      forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue
    )
    try identityKeychain.set(
      "original-identity-token",
      forKey: ClerkKeychainKey.clerkDeviceToken.rawValue
    )

    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: Clerk.shared.runtimeScope),
      keychain: sharedKeychain,
      appLocalKeychain: appLocalKeychain,
      identityKeychain: identityKeychain
    )
    try dependencies.configurationManager.configure(
      publishableKey: testPublishableKey,
      options: .init(
        keychainConfig: .init(
          service: "test.shared.service",
          accessGroup: "test.shared.group"
        ),
        sharedSessionSync: .enabled
      )
    )
    let sharedState = try keychainContents(in: sharedKeychain)
    let appLocalState = try keychainContents(in: appLocalKeychain)
    let identityState = try keychainContents(in: identityKeychain)
    let snapshot = try Clerk.captureKeychainSnapshot(in: [dependencies])

    #expect(throws: AdoptionMarkerFailingKeychain.WriteError.self) {
      try Clerk.prepareSharedSessionAdoptionIfNeeded(dependencies: dependencies)
    }
    #expect(
      try identityKeychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
        == "persisted-device-token"
    )
    #expect(try identityKeychain.hasItem(forKey: ClerkKeychainKey.cachedClient.rawValue))
    #expect(try identityKeychain.hasItem(forKey: ClerkKeychainKey.cachedEnvironment.rawValue))

    try snapshot.restore()

    #expect(try keychainContents(in: sharedKeychain) == sharedState)
    #expect(try keychainContents(in: appLocalKeychain) == appLocalState)
    #expect(try keychainContents(in: identityKeychain) == identityState)
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
    let sessionService = MockSessionService(fetchToken: { _, _ in
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
    await SessionTokensCache.shared.insertToken(
      .init(jwt: cachedJWT),
      cacheKey: Session.mock.tokenCacheKey(template: nil)
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
          let token = await SessionTokensCache.shared.getToken(cacheKey: oldValue.tokenCacheKey(template: nil))?.jwt
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
    let oldKeychain = SlowKeychain(delay: 0.5)
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: Clerk.shared.runtimeScope),
      keychain: oldKeychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )
    Clerk.shared.performConfiguration(dependencies: dependencies)
    Clerk.shared.client = .mock
    let staleSession = try #require(Clerk.shared.session)
    await SessionTokensCache.shared.insertToken(
      .init(jwt: cachedJWT),
      cacheKey: staleSession.tokenCacheKey(template: nil)
    )

    let reconfigureTask = Task { @MainActor in
      try await Clerk.reconfigure(publishableKey: publishableKey(for: "token-read-window.clerk.example.com"))
    }
    try await Task.sleep(for: .milliseconds(20))

    do {
      _ = try await staleSession.getToken()
      Issue.record("Expected token reads during reconfiguration to be cancelled")
    } catch is CancellationError {
      // Expected.
    } catch {
      Issue.record("Expected CancellationError, got \(error)")
    }

    let reconfigured = try await reconfigureTask.value
    reconfigured.cleanupManagers()
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
  func concurrentReconfigureThrowsWhileFirstReconfigureIsInProgress() async throws {
    let slowKeychain = SlowKeychain(delay: 0.2)
    let dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: Clerk.shared.runtimeScope),
      keychain: slowKeychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )
    Clerk.shared.performConfiguration(dependencies: dependencies)
    Clerk.shared.client = .mock

    let firstReconfigure = Task { @MainActor in
      try await Clerk.reconfigure(publishableKey: publishableKey(for: "first-target.clerk.example.com"))
    }
    try await Task.sleep(for: .milliseconds(20))

    do {
      _ = try await Clerk.reconfigure(publishableKey: publishableKey(for: "second-target.clerk.example.com"))
      Issue.record("Expected overlapping reconfigure to throw")
    } catch let error as ClerkClientError {
      #expect(error.message?.contains("already reconfiguring") == true)
    } catch {
      Issue.record("Expected ClerkClientError, got \(error)")
    }

    let reconfigured = try await firstReconfigure.value
    defer { reconfigured.cleanupManagers() }
    #expect(reconfigured.publishableKey == publishableKey(for: "first-target.clerk.example.com"))
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
      // Expected.
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
      // Expected.
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
      // Expected.
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

  private func seedIdentityCache(
    in keychain: any KeychainStorage
  ) throws {
    let values = try [
      ClerkKeychainKey.clerkDeviceToken.rawValue: Data("persisted-device-token".utf8),
      ClerkKeychainKey.cachedClient.rawValue: JSONEncoder.clerkEncoder.encode(Client.mock),
      ClerkKeychainKey.cachedClientServerDate.rawValue: Data("100".utf8),
      ClerkKeychainKey.cachedEnvironment.rawValue: JSONEncoder.clerkEncoder.encode(
        Clerk.Environment.mock
      ),
    ]

    for (key, data) in values {
      try keychain.set(data, forKey: key)
    }
  }

  private func expectIdentityCache(
    in keychain: any KeychainStorage
  ) throws {
    #expect(
      try keychain.string(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
        == "persisted-device-token"
    )

    let clientData = try #require(
      try keychain.data(forKey: ClerkKeychainKey.cachedClient.rawValue)
    )
    #expect(try JSONDecoder.clerkDecoder.decode(Client.self, from: clientData).id == Client.mock.id)

    let serverDate = try #require(
      try keychain.string(forKey: ClerkKeychainKey.cachedClientServerDate.rawValue)
    )
    #expect(TimeInterval(serverDate) == 100)

    let environmentData = try #require(
      try keychain.data(forKey: ClerkKeychainKey.cachedEnvironment.rawValue)
    )
    #expect(
      try JSONDecoder.clerkDecoder.decode(Clerk.Environment.self, from: environmentData) == .mock
    )
  }

  private func keychainContents(
    in keychain: any KeychainStorage
  ) throws -> [String: Data] {
    try ClerkKeychainKey.allCases.reduce(into: [:]) { contents, key in
      if let data = try keychain.data(forKey: key.rawValue) {
        contents[key.rawValue] = data
      }
    }
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

private final class PartiallyFailingDeleteKeychain: KeychainStorage, @unchecked Sendable {
  private enum DeleteError: Error {
    case failed
  }

  private let lock = NSLock()
  private var successfulDeletesBeforeFailure: Int?
  private var storage: [String: Data] = [:]

  init(successfulDeletesBeforeFailure: Int) {
    self.successfulDeletesBeforeFailure = successfulDeletesBeforeFailure
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
    lock.lock()
    defer { lock.unlock() }

    if let remaining = successfulDeletesBeforeFailure {
      if remaining == 0 {
        successfulDeletesBeforeFailure = nil
        throw DeleteError.failed
      }
      successfulDeletesBeforeFailure = remaining - 1
    }

    storage[key] = nil
  }

  func hasItem(forKey key: String) throws -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return storage[key] != nil
  }
}

private final class AdoptionMarkerFailingKeychain: KeychainStorage, @unchecked Sendable {
  enum WriteError: Error {
    case markerWriteFailed
  }

  private let lock = NSLock()
  private var storage: [String: Data] = [:]

  func set(_ data: Data, forKey key: String) throws {
    guard key != ClerkKeychainKey.sharedSessionSyncAdopted.rawValue else {
      throw WriteError.markerWriteFailed
    }

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
