@testable import ClerkKit
import ClerkSnapshots
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct SignInTests {
  init() {
    configureClerkForTesting()
  }

  private func configureService(_ service: MockSignInService) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      signInService: service
    )
    try! (Clerk.shared.dependencies as! MockDependencyContainer)
      .configurationManager
      .configure(publishableKey: testPublishableKey, options: .init())
  }

  @Test
  func sendEmailLinkSavesPendingFlowBeforePrepare() async throws {
    let keychain = InMemoryKeychain()
    let signIn = SignIn(
      id: "sign_in_123",
      status: .needsFirstFactor,
      identifier: "test@example.com",
      supportedFirstFactors: [
        Factor(
          strategy: .emailLink,
          emailAddressId: "ema_123",
          safeIdentifier: "test@example.com"
        ),
      ]
    )
    Clerk.engineClient = ThrowingJSEngine(message: "Prepare failed.")
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain
    )
    let magicLinkStore = Clerk.shared.dependencies.magicLinkStore

    await #expect(throws: ClerkClientError.self) {
      try await signIn.sendEmailLink()
    }
    let pendingFlow = try #require(magicLinkStore.load())
    #expect(pendingFlow.kind == .signIn)
    #expect(pendingFlow.flowId == signIn.id)
    #expect(pendingFlow.codeVerifier.isEmpty == false)
  }

  @Test
  func sendEmailLinkDoesNotPrepareWhenSavingPendingFlowFails() async throws {
    let engine = CountingJSEngine()
    let signIn = SignIn(
      id: "sign_in_123",
      status: .needsFirstFactor,
      identifier: "test@example.com",
      supportedFirstFactors: [
        Factor(
          strategy: .emailLink,
          emailAddressId: "ema_123",
          safeIdentifier: "test@example.com"
        ),
      ]
    )
    Clerk.engineClient = engine
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: SetFailingKeychain()
    )

    await #expect(throws: SetFailingKeychain.Failure.self) {
      try await signIn.sendEmailLink()
    }
    #expect(engine.invokeCount == 0)
  }

  @Test
  func handleTransferFlowSkipsSignUpWhenNotTransferable() async throws {
    var signIn = SignIn.mock
    signIn.firstFactorVerification = Verification(status: .transferable)

    let engine = RecordingEngineClient()
    engine.nativeCompletionResult = .signIn(signIn)
    Clerk.engineClient = engine
    let result = try await signIn.handleTransferFlow(transferable: false)

    switch result {
    case .signIn:
      break
    case .signUp:
      #expect(Bool(false))
    }
  }
}

@MainActor
private final class ThrowingJSEngine: ClerkEngineClient {
  let message: String

  init(message: String) {
    self.message = message
  }

  func invoke(_: ClerkJSInvocation) async throws -> JSONValue {
    throw ClerkClientError(message: String.LocalizationValue(stringLiteral: message))
  }
}

@MainActor
private final class CountingJSEngine: ClerkEngineClient {
  var invokeCount = 0

  func invoke(_: ClerkJSInvocation) async throws -> JSONValue {
    invokeCount += 1
    return .null
  }
}
