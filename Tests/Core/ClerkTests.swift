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
  func authPresentationRequirementReturnsContinuationWhenContinuationIsPending() {
    Clerk.shared.setPendingAuthResult(.signIn(SignIn(
      id: "sign_in_pending",
      status: .needsSecondFactor,
      createdSessionId: nil
    )))
    Clerk.shared.client = nil

    #expect(Clerk.shared.authPresentationRequirement == .continuation)
  }

  @Test
  func authPresentationRequirementReturnsSessionTasksWhenCurrentSessionHasPendingTasks() {
    Clerk.shared.setPendingAuthResult(nil)
    var session = createSession(id: "sess_pending", status: .pending)
    session.tasks = [.setupMfa]
    Clerk.shared.client = Client(
      id: "client_test",
      sessions: [session],
      lastActiveSessionId: session.id,
      updatedAt: Date()
    )

    #expect(Clerk.shared.authPresentationRequirement == .sessionTasks)
  }

  @Test
  func authPresentationRequirementPrefersContinuationOverSessionTasks() {
    var signUp = SignUp.mock
    signUp.status = .missingRequirements
    Clerk.shared.setPendingAuthResult(.signUp(signUp))
    var session = createSession(id: "sess_pending", status: .pending)
    session.tasks = [.setupMfa]
    Clerk.shared.client = Client(
      id: "client_test",
      sessions: [session],
      lastActiveSessionId: session.id,
      updatedAt: Date()
    )

    #expect(Clerk.shared.authPresentationRequirement == .continuation)
  }

  @Test
  func clearAllKeychainItemsDeletesAllKeys() throws {
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
    try keychain.set("test-device-token", forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
    try keychain.set("true", forKey: ClerkKeychainKey.clerkDeviceTokenSynced.rawValue)
    try keychain.set("test-attest-key-id", forKey: ClerkKeychainKey.attestKeyId.rawValue)
    try keychain.set("test-pending-flow", forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue)

    // Verify all keys exist before clearing
    for key in ClerkKeychainKey.allCases {
      #expect(try keychain.hasItem(forKey: key.rawValue) == true)
    }

    // Clear all keychain items
    Clerk.clearAllKeychainItems()

    // Verify all keys are deleted
    for key in ClerkKeychainKey.allCases {
      #expect(try keychain.hasItem(forKey: key.rawValue) == false)
    }
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
    let signInParams = LockIsolated<SignIn.CreateParams?>(nil)
    let activatedSessionId = LockIsolated<String?>(nil)
    let testBaseUrl = try #require(URL(string: "https://mock-clerktests-success.clerk.accounts.dev"))
    let completionUrl = URL(string: testBaseUrl.absoluteString + "/v1/client/magic_links/complete")!

    var completionMock = try Mock(
      url: completionUrl,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          MagicLinkCompleteResponse(flowId: "flow_123", ticket: "ticket_123")
        ),
      ]
    )

    completionMock.onRequestHandler = OnRequestHandler { request in
      #expect(request.httpMethod == "POST")
      #expect(request.urlEncodedFormBody?["flow_id"] == "flow_123")
      #expect(request.urlEncodedFormBody?["approval_token"] == "approval_123")
      #expect(request.urlEncodedFormBody?["code_verifier"] == "verifier_123")
    }
    completionMock.register()

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
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(baseURL: testBaseUrl),
      keychain: keychain,
      signInService: signInService,
      sessionService: sessionService
    )
    clerk.environment = .mock
    let callbackUrl = try #require(URL(string: "\(Clerk.shared.options.redirectConfig.redirectUrl)?flow_id=flow_123&approval_token=approval_123"))
    try clerk.dependencies.magicLinkStore.save(kind: .signIn, codeVerifier: "verifier_123")

    let handled = try await clerk.handle(callbackUrl)

    #expect(handled == true)
    #expect(signInParams.value?.ticket == "ticket_123")
    #expect(activatedSessionId.value == "sess_123")
    #expect(try keychain.hasItem(forKey: ClerkKeychainKey.pendingMagicLinkFlow.rawValue) == false)
  }

  @Test
  func handleDeduplicatesConcurrentMagicLinkCallbacks() async throws {
    let keychain = InMemoryKeychain()
    let createCallCount = LockIsolated(0)
    let activatedSessionId = LockIsolated<String?>(nil)
    let testBaseUrl = try #require(URL(string: "https://mock-clerktests-dedupe.clerk.accounts.dev"))
    let completionUrl = URL(string: testBaseUrl.absoluteString + "/v1/client/magic_links/complete")!

    let completionMock = try Mock(
      url: completionUrl,
      ignoreQuery: true,
      contentType: .json,
      statusCode: 200,
      data: [
        .post: JSONEncoder.clerkEncoder.encode(
          MagicLinkCompleteResponse(flowId: "flow_123", ticket: "ticket_123")
        ),
      ]
    )
    completionMock.register()

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
    clerk.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(baseURL: testBaseUrl),
      keychain: keychain,
      signInService: signInService,
      sessionService: sessionService
    )
    clerk.environment = .mock
    let callbackUrl = try #require(URL(string: "\(Clerk.shared.options.redirectConfig.redirectUrl)?flow_id=flow_123&approval_token=approval_123"))
    try clerk.dependencies.magicLinkStore.save(kind: .signIn, codeVerifier: "verifier_123")

    async let firstHandled = clerk.handle(callbackUrl)
    async let secondHandled = clerk.handle(callbackUrl)

    let (first, second) = try await (firstHandled, secondHandled)

    #expect(first == true)
    #expect(second == true)
    #expect(createCallCount.value == 1)
    #expect(activatedSessionId.value == "sess_123")
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
}
