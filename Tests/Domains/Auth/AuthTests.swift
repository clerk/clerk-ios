@testable import ClerkKit
#if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
import AuthenticationServices
#endif
import ConcurrencyExtras
import Foundation
import Mocker
import Testing

@MainActor
@Suite(.serialized)
struct AuthTests {
  init() {
    configureClerkForTesting()
  }

  private func configureDependencies(
    signInService: MockSignInService? = nil,
    sessionService: MockSessionService? = nil,
    environment: Clerk.Environment? = .mock,
    keychain: (any KeychainStorage)? = nil,
    baseURL: URL = mockBaseUrl,
    options: Clerk.Options = .init()
  ) {
    configureClerkForTesting()
    let apiClient = createMockAPIClient(baseURL: baseURL)
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: apiClient,
      keychain: keychain,
      signInService: signInService,
      sessionService: sessionService
    )
    try! (Clerk.shared.dependencies as! MockDependencyContainer)
      .configurationManager
      .configure(publishableKey: testPublishableKey, options: options)
    Clerk.shared.environment = environment
    Clerk.shared.setCallbackContinuation(nil)
  }

  private func enabledBiometricCredentialEnvironment() -> Clerk.Environment {
    var environment = Clerk.Environment.mock
    environment.authConfig.nativeSettings = .init(
      apiEnabled: true,
      biometricSignInEnabled: true
    )
    return environment
  }

  @Test
  func urlHandlingCoordinatorDeduplicatesConcurrentRoutes() async throws {
    let coordinator = URLHandlingCoordinator()
    let invocationCount = LockIsolated(0)
    let route = ClerkURLRoute.magicLink(flowId: "flow_123", approvalToken: "approval_123")
    let expectedResult = TransferFlowResult.signIn(SignIn(
      id: "sign_in_123",
      status: .complete,
      createdSessionId: "sess_123"
    ))

    async let first = coordinator.handle(route) {
      invocationCount.withValue { $0 += 1 }
      try await Task.sleep(for: .milliseconds(50))
      return expectedResult
    }
    async let second = coordinator.handle(route) {
      invocationCount.withValue { $0 += 1 }
      return expectedResult
    }

    let (firstResult, secondResult) = try await (first, second)
    let firstSignIn = switch firstResult {
    case .signIn(let signIn):
      signIn
    case .signUp:
      Issue.record("Expected sign-in result for first deduped route.")
      throw ClerkClientError(message: "Expected sign-in result.")
    }
    let secondSignIn = switch secondResult {
    case .signIn(let signIn):
      signIn
    case .signUp:
      Issue.record("Expected sign-in result for second deduped route.")
      throw ClerkClientError(message: "Expected sign-in result.")
    }

    #expect(firstSignIn.createdSessionId == "sess_123")
    #expect(secondSignIn.createdSessionId == "sess_123")
    #expect(invocationCount.value == 1)
  }

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @Test
  func normalizedAppleScopesDropsFullNameWhenBothNameFieldsAreDisabled() {
    var environment = Clerk.Environment.mock
    environment.userSettings.attributes.firstName.enabled = false
    environment.userSettings.attributes.lastName.enabled = false

    let scopes = Auth.normalizedAppleScopes(
      [.email, .fullName],
      environment: environment
    )

    #expect(scopes == [.email])
  }

  @Test
  func normalizedAppleScopesKeepsFullNameWhenEitherNameFieldIsEnabled() {
    var environment = Clerk.Environment.mock
    environment.userSettings.attributes.firstName.enabled = true
    environment.userSettings.attributes.lastName.enabled = false

    let scopes = Auth.normalizedAppleScopes(
      [.email, .fullName],
      environment: environment
    )

    #expect(scopes == [.email, .fullName])
  }

  @Test
  func normalizedAppleScopesKeepsFullNameWhenEnvironmentIsUnavailable() {
    let scopes = Auth.normalizedAppleScopes(
      [.email, .fullName],
      environment: nil
    )

    #expect(scopes == [.email, .fullName])
  }
  #endif

  @Test
  func recoveredSessionActivationWaitsForAuthViewCompletion() throws {
    configureDependencies()
    Clerk.shared.client = nil
    let registration = try #require(Clerk.shared.registerAuthFlow())
    let sessionId = try #require(Client.mock.currentSession?.id)
    let activation = try #require(Clerk.shared.beginAuthSessionActivation(
      sessionId: sessionId,
      ownerId: registration.id
    ))
    Clerk.shared.client = .mock

    Clerk.shared.authSessionActivationDidFinish(activation: activation)

    let snapshot = try #require(Clerk.shared.authFlowSnapshot(for: registration))
    guard case .awaiting(let work, _) = snapshot.phase else {
      Issue.record("Expected the recovered session to await AuthView completion")
      return
    }
    #expect(Clerk.shared.isAuthFlowComplete == false)
    #expect(Clerk.shared.completeAuthFlow(work))
    #expect(Clerk.shared.isAuthFlowComplete)
    withExtendedLifetime(registration) {}
  }
}
