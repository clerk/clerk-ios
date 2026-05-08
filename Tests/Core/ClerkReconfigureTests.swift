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

    #expect(Clerk.shared === original)
    #expect((Clerk.shared.dependencies as AnyObject) === (originalDependencies as AnyObject))
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
  func failedReconfigureLeavesPreviousRuntimeUntouched() async throws {
    let original = Clerk.shared
    let previousEpoch = Clerk.shared.configurationEpoch
    let throwingKeychain = ThrowingDeleteKeychain()
    let previousDependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: Clerk.shared.runtimeScope),
      keychain: throwingKeychain,
      telemetryCollector: Clerk.shared.dependencies.telemetryCollector
    )
    original.performConfiguration(dependencies: previousDependencies)
    original.client = .mock
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
    } catch let error as ClerkClientError {
      #expect(error.message?.contains("Unable to clear Clerk keychain items") == true)
    } catch {
      Issue.record("Expected ClerkClientError, got \(error)")
    }

    #expect(Clerk.shared === original)
    #expect(Clerk.shared.configurationEpoch == previousEpoch)
    #expect((Clerk.shared.dependencies as AnyObject) === (previousDependencies as AnyObject))
    #expect(Clerk.shared.client?.id == Client.mock.id)
    #expect(Clerk.shared.environment == .mock)
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
    Clerk.resetSharedInstanceForTesting()
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
    Clerk.resetSharedInstanceForTesting()

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

private final class ThrowingDeleteKeychain: KeychainStorage, @unchecked Sendable {
  private enum DeleteError: Error {
    case failed
  }

  private let lock = NSLock()
  private var storage: [String: Data] = [:]

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

  func deleteItem(forKey _: String) throws {
    throw DeleteError.failed
  }

  func hasItem(forKey key: String) throws -> Bool {
    lock.lock()
    defer { lock.unlock() }
    return storage[key] != nil
  }
}
