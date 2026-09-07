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
  func verifyCodeThrowsWhenFirstFactorVerificationStrategyIsNotCodeBased() async throws {
    var signIn = SignIn.mock
    signIn.firstFactorVerification = Verification(
      status: .unverified,
      strategy: .password
    )

    let captured = LockIsolated<(String, ClerkKit.SignIn.AttemptFirstFactorParams)?>(nil)
    let service = MockSignInService(attemptFirstFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    do {
      _ = try await signIn.verifyCode("123456")
      Issue.record("Expected ClerkClientError.")
    } catch let error as ClerkClientError {
      #expect(error.message == "Unable to verify code for strategy 'password'.")
    } catch {
      Issue.record("Wrong error type: \(error)")
    }

    #expect(captured.value == nil)
  }

  @Test
  func verifyCodeThrowsWhenFirstFactorVerificationStrategyIsMissing() async throws {
    var signIn = SignIn.mock
    signIn.firstFactorVerification = nil

    let captured = LockIsolated<(String, ClerkKit.SignIn.AttemptFirstFactorParams)?>(nil)
    let service = MockSignInService(attemptFirstFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    do {
      _ = try await signIn.verifyCode("123456")
      Issue.record("Expected ClerkClientError.")
    } catch let error as ClerkClientError {
      #expect(error.message == "Unable to verify code because no first factor strategy is set.")
    } catch {
      Issue.record("Wrong error type: \(error)")
    }

    #expect(captured.value == nil)
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

  @Test
  func completeEnterpriseSSOReloadsWithNonce() async throws {
    let signIn = SignIn.mock
    var reloadedSignIn = SignIn.mock
    reloadedSignIn.firstFactorVerification = Verification(status: .verified)

    let engine = RecordingEngineClient()
    engine.signInOnReload = reloadedSignIn
    Clerk.engineClient = engine

    let callbackURL = try #require(URL(string: "myapp://callback?rotating_token_nonce=test_nonce"))
    let result = try await signIn.completeEnterpriseSSO(callbackURL: callbackURL)

    #expect(engine.reloadedNonce == "test_nonce")

    switch result {
    case .signIn(let updatedSignIn):
      #expect(updatedSignIn == reloadedSignIn)
    case .signUp:
      Issue.record("Expected sign-in result.")
    }
  }

  @Test
  func completeEnterpriseSSOTransfersToSignUpWithoutNonce() async throws {
    let metadata: JSON = ["plan": "pro"]
    let signIn = SignIn.mock
    var reloadedSignIn = SignIn.mock
    reloadedSignIn.firstFactorVerification = Verification(status: .transferable)

    let engine = RecordingEngineClient()
    engine.signInOnReload = reloadedSignIn
    Clerk.engineClient = engine

    let callbackURL = try #require(URL(string: "myapp://callback"))
    engine.nativeCompletionResult = .signUp(SignUp.mock)
    let result = try await signIn.completeEnterpriseSSO(
      callbackURL: callbackURL,
      unsafeMetadata: metadata
    )

    #expect(engine.reloadedNonce == nil)
    #expect(engine.nativeCompletionMetadata == metadata.jsonValue)

    switch result {
    case .signUp(let signUp):
      #expect(signUp == .mock)
    case .signIn:
      Issue.record("Expected sign-up result.")
    }
  }

  @Test
  func completeEnterpriseSSODoesNotTransferWhenNotTransferable() async throws {
    let signIn = SignIn.mock
    var reloadedSignIn = SignIn.mock
    reloadedSignIn.firstFactorVerification = Verification(status: .transferable)

    let engine = RecordingEngineClient()
    engine.signInOnReload = reloadedSignIn
    Clerk.engineClient = engine

    let callbackURL = try #require(URL(string: "myapp://callback"))
    let result = try await signIn.completeEnterpriseSSO(
      callbackURL: callbackURL,
      transferable: false
    )

    #expect(engine.reloadedNonce == nil)

    switch result {
    case .signIn(let updatedSignIn):
      #expect(updatedSignIn == reloadedSignIn)
    case .signUp:
      Issue.record("Expected sign-in result.")
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
