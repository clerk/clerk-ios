@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
struct ForceUpdateTests {
  private enum TestError: Error {
    case environmentRefreshFailed
    case timedOut
  }

  @Test
  func isForceUpdateRequiredIsFalseWhenEnvironmentIsMissing() {
    let clerk = Clerk()

    #expect(clerk.isForceUpdateRequired == false)
  }

  @Test
  func isForceUpdateRequiredReflectsAppVersionSupportStatus() {
    let clerk = Clerk()
    clerk.appVersionSupportStatus = .init(
      isSupported: false,
      minimumVersion: "2.0.0",
      updateURL: URL(string: "https://apps.apple.com/app/id123456789")
    )

    #expect(clerk.isForceUpdateRequired)
    #expect(clerk.appVersionSupportStatus.minimumVersion == "2.0.0")
  }

  @Test
  func cachedBlockingEnvironmentDoesNotRequireForceUpdate() throws {
    let clerk = Clerk(appBundleID: testBundleID, appVersion: testAppVersion)
    let keychain = InMemoryKeychain()
    let cacheManager = CacheManager(coordinator: clerk, keychain: keychain)
    clerk.cacheManager = cacheManager
    defer { clerk.cleanupManagers() }
    try keychain.set(
      JSONEncoder.clerkEncoder.encode(blockingEnvironment()),
      forKey: ClerkKeychainKey.cachedEnvironment.rawValue
    )

    cacheManager.loadCachedData(hydrateIdentity: false)

    #expect(clerk.environment == blockingEnvironment())
    #expect(clerk.appVersionSupportStatus == .supportedDefault)
  }

  @Test
  func cachedBlockingEnvironmentFollowedByFailedRefreshRemainsAllowed() async throws {
    let service = MockEnvironmentService(get: { throw TestError.environmentRefreshFailed })
    let clerk = makeClerk(environmentService: service)
    let keychain = InMemoryKeychain()
    let cacheManager = CacheManager(coordinator: clerk, keychain: keychain)
    clerk.cacheManager = cacheManager
    defer { clerk.cleanupManagers() }
    try keychain.set(
      JSONEncoder.clerkEncoder.encode(blockingEnvironment()),
      forKey: ClerkKeychainKey.cachedEnvironment.rawValue
    )
    cacheManager.loadCachedData(hydrateIdentity: false)

    await #expect(throws: TestError.environmentRefreshFailed) {
      try await clerk.refreshEnvironment()
    }

    #expect(clerk.appVersionSupportStatus == .supportedDefault)
  }

  @Test
  func synchronizedBlockingEnvironmentDoesNotRequireForceUpdate() {
    let clerk = Clerk(appBundleID: testBundleID, appVersion: testAppVersion)

    clerk.environment = blockingEnvironment()

    #expect(clerk.environment == blockingEnvironment())
    #expect(clerk.appVersionSupportStatus == .supportedDefault)
  }

  @Test
  func freshlyFetchedBlockingEnvironmentProvisionallyRequiresForceUpdate() async throws {
    let service = MockEnvironmentService(get: { [self] in blockingEnvironment() })
    let clerk = makeClerk(environmentService: service)

    _ = try await clerk.refreshEnvironment()

    #expect(!clerk.appVersionSupportStatus.isSupported)
    #expect(clerk.appVersionSupportStatus.minimumVersion == "999.0.0")
  }

  @Test
  func freshEnvironmentWithoutMatchingPolicyClearsProvisionalBlock() async throws {
    let service = MockEnvironmentService(get: { [self] in blockingEnvironment() })
    let clerk = makeClerk(environmentService: service)
    _ = try await clerk.refreshEnvironment()
    #expect(!clerk.appVersionSupportStatus.isSupported)
    service.getHandler = { .mock }

    _ = try await clerk.refreshEnvironment()

    #expect(clerk.appVersionSupportStatus == .supportedDefault)
  }

  @Test
  func failedEnvironmentRefreshPreservesProvisionalStatus() async throws {
    let service = MockEnvironmentService(get: { [self] in blockingEnvironment() })
    let clerk = makeClerk(environmentService: service)
    _ = try await clerk.refreshEnvironment()
    service.getHandler = { throw TestError.environmentRefreshFailed }

    await #expect(throws: TestError.environmentRefreshFailed) {
      try await clerk.refreshEnvironment()
    }

    #expect(!clerk.appVersionSupportStatus.isSupported)
    #expect(clerk.appVersionSupportStatus.minimumVersion == "999.0.0")
  }

  @Test
  func foregroundClientRefreshClearsServerEnforcedBlockAfterSupportedResponse() async throws {
    let clerk = Clerk()
    let baseURL = try #require(
      URL(string: "https://force-update-\(UUID().uuidString.lowercased()).clerk.test")
    )
    let clientURL = baseURL.appendingPathComponent("v1/client")
    let apiClient = createMockAPIClient(baseURL: baseURL, runtimeScope: clerk.runtimeScope)
    let refreshCompleted = LockIsolated(false)
    let tokenRequested = LockIsolated(false)
    let clientService = CompletionReportingClientService(
      wrapped: ClientService(apiClient: apiClient),
      completion: {
        refreshCompleted.setValue(true)
      }
    )
    clerk.dependencies = MockDependencyContainer(
      apiClient: apiClient,
      clientService: clientService
    )
    clerk.client = .mock
    clerk.sessionPollingManager = SessionPollingManager(
      sessionProvider: clerk,
      requestToken: { session in
        #expect(session.id == Client.mock.currentSession?.id)
        tokenRequested.setValue(true)
      }
    )
    defer { clerk.cleanupManagers() }

    let mock = try Mock(
      url: clientURL,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(
          ClientResponse<Client?>(response: .mock, client: .mock)
        ),
      ],
      additionalHeaders: [
        "Authorization": "client-token",
        ClerkErrorThrowingResponseMiddleware.appVersionStatusHeader:
          ClerkErrorThrowingResponseMiddleware.supportedAppVersionStatus,
      ]
    )
    mock.register()
    clerk.applyUnsupportedAppVersionMeta(
      .object([
        "platform": .string("ios"),
        "app_identifier": .string("com.example.force-update"),
        "current_version": .string("1.0.0"),
        "minimum_version": .string("2.0.0"),
        "update_url": .string("https://apps.apple.com/app/id123"),
      ]),
      requestBundleID: "com.example.force-update",
      requestVersion: "1.0.0",
      requestSequence: 0
    )
    #expect(!clerk.appVersionSupportStatus.isSupported)

    await clerk.onWillEnterForeground()
    try await waitUntil {
      refreshCompleted.value && tokenRequested.value
    }

    #expect(refreshCompleted.value)
    #expect(tokenRequested.value)
    #expect(clerk.appVersionSupportStatus == .supportedDefault)
  }

  @Test
  func blockedAppRevalidatesAndResumesTokenRefreshWithoutForegroundTransition() async throws {
    let revalidationSleepCount = LockIsolated(0)
    let clerk = Clerk(
      appBundleID: testBundleID,
      appVersion: testAppVersion,
      appVersionRevalidationInitialDelay: .zero,
      appVersionRevalidationMaximumDelay: .zero,
      appVersionRevalidationSleep: { _ in
        revalidationSleepCount.withValue { $0 += 1 }
        await Task.yield()
      }
    )
    let baseURL = try #require(
      URL(string: "https://force-update-revalidation-\(UUID().uuidString.lowercased()).clerk.test")
    )
    let clientURL = baseURL.appendingPathComponent("v1/client")
    let apiClient = createMockAPIClient(baseURL: baseURL, runtimeScope: clerk.runtimeScope)
    let clientRefreshCount = LockIsolated(0)
    let tokenRequestCount = LockIsolated(0)
    let clientService = CompletionReportingClientService(
      wrapped: ClientService(apiClient: apiClient),
      completion: {
        clientRefreshCount.withValue { $0 += 1 }
      }
    )
    clerk.dependencies = MockDependencyContainer(
      apiClient: apiClient,
      clientService: clientService
    )
    clerk.client = .mock
    clerk.sessionPollingManager = SessionPollingManager(
      sessionProvider: clerk,
      requestToken: { session in
        #expect(session.id == Client.mock.currentSession?.id)
        tokenRequestCount.withValue { $0 += 1 }
      }
    )
    defer { clerk.cleanupManagers() }

    let mock = try Mock(
      url: clientURL,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .get: JSONEncoder.clerkEncoder.encode(
          ClientResponse<Client?>(response: .mock, client: .mock)
        ),
      ],
      additionalHeaders: [
        "Authorization": "client-token",
        ClerkErrorThrowingResponseMiddleware.appVersionStatusHeader:
          ClerkErrorThrowingResponseMiddleware.supportedAppVersionStatus,
      ]
    )
    mock.register()
    clerk.applyUnsupportedAppVersionMeta(
      .object([
        "platform": .string("ios"),
        "app_identifier": .string(testBundleID),
        "current_version": .string(testAppVersion),
        "minimum_version": .string("2.0.0"),
        "update_url": .string("https://apps.apple.com/app/id123"),
      ]),
      requestBundleID: testBundleID,
      requestVersion: testAppVersion,
      requestSequence: 0
    )
    #expect(!clerk.appVersionSupportStatus.isSupported)

    try await waitUntil {
      clerk.appVersionSupportStatus.isSupported && tokenRequestCount.value == 1
    }

    #expect(revalidationSleepCount.value == 1)
    #expect(clientRefreshCount.value == 1)
    #expect(tokenRequestCount.value == 1)
    #expect(clerk.appVersionSupportStatus == .supportedDefault)
  }

  @Test
  func backgroundingCancelsBlockedAppRevalidation() async throws {
    let sleepStarted = LockIsolated(false)
    let sleepCancelled = LockIsolated(false)
    let clientRefreshCount = LockIsolated(0)
    let clerk = Clerk(
      appBundleID: testBundleID,
      appVersion: testAppVersion,
      appVersionRevalidationSleep: { _ in
        sleepStarted.setValue(true)
        do {
          try await Task.sleep(for: .seconds(60))
        } catch {
          sleepCancelled.setValue(true)
          throw error
        }
      }
    )
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      clientService: MockClientService {
        clientRefreshCount.withValue { $0 += 1 }
        return .mock
      }
    )
    clerk.sessionPollingManager = SessionPollingManager(sessionProvider: clerk)
    defer { clerk.cleanupManagers() }

    clerk.applyUnsupportedAppVersionMeta(
      .object([
        "platform": .string("ios"),
        "app_identifier": .string(testBundleID),
        "current_version": .string(testAppVersion),
        "minimum_version": .string("2.0.0"),
        "update_url": .string("https://apps.apple.com/app/id123"),
      ]),
      requestBundleID: testBundleID,
      requestVersion: testAppVersion,
      requestSequence: 0
    )
    try await waitUntil { sleepStarted.value }

    await clerk.onDidEnterBackground()
    try await waitUntil { sleepCancelled.value }

    #expect(clientRefreshCount.value == 0)
    #expect(!clerk.appVersionSupportStatus.isSupported)
  }

  private func makeClerk(environmentService: MockEnvironmentService) -> Clerk {
    let clerk = Clerk(
      appBundleID: testBundleID,
      appVersion: testAppVersion
    )
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(runtimeScope: clerk.runtimeScope),
      environmentService: environmentService
    )
    return clerk
  }

  private func blockingEnvironment() -> Clerk.Environment {
    var environment = Clerk.Environment.mock
    environment.nativeAppSettings = .init(
      minimumSupportedVersion: .init(
        ios: [
          .init(
            bundleId: testBundleID,
            minimumVersion: "999.0.0",
            updateUrl: "https://apps.apple.com/app/id123"
          ),
        ]
      )
    )
    return environment
  }

  private func waitUntil(
    timeout: Duration = .seconds(1),
    _ condition: () -> Bool
  ) async throws {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
      if condition() {
        return
      }
      try await Task.sleep(for: .milliseconds(10))
    }

    guard condition() else {
      throw TestError.timedOut
    }
  }
}

private let testBundleID = "com.example.force-update-tests"
private let testAppVersion = "1.0.0"

private final class CompletionReportingClientService: ClientServiceProtocol {
  let wrapped: any ClientServiceProtocol
  let completion: @Sendable () -> Void

  init(
    wrapped: any ClientServiceProtocol,
    completion: @escaping @Sendable () -> Void
  ) {
    self.wrapped = wrapped
    self.completion = completion
  }

  @MainActor
  func getResponse(skipClientId: Bool) async throws -> ClientServiceResponse {
    defer { completion() }
    return try await wrapped.getResponse(skipClientId: skipClientId)
  }
}
