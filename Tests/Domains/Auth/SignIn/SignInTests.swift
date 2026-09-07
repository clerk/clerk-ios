@testable import ClerkKit
import ClerkSnapshots
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct SignInTests {
  private enum PasskeyTestError: Error {
    case preparationFailed
    case secondFactorPreparationFailed
    case authorizationFailed
    case attemptFailed
    case secondFactorAttemptFailed
  }

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

  @Test(arguments: [
    PasskeyAuthenticationFailure.Stage.preparingFirstFactor,
    .requestingAuthorization,
    .attemptingFirstFactor,
  ])
  func passkeyFailureContextIdentifiesFailureStage(
    _ expectedStage: PasskeyAuthenticationFailure.Stage
  ) async {
    let signIn = SignIn.mock
    let engine = RecordingEngineClient()
    engine.signInOnReload = .mock
    if expectedStage == .preparingFirstFactor {
      engine.instanceMethodErrors["prepareFirstFactor"] = PasskeyTestError.preparationFailed
    }
    if expectedStage == .attemptingFirstFactor {
      engine.instanceMethodErrors["attemptFirstFactor"] = PasskeyTestError.attemptFailed
    }
    Clerk.engineClient = engine

    do {
      _ = try await signIn.authenticateWithPasskeyWithFailureContext { _ in
        if expectedStage == .requestingAuthorization {
          throw PasskeyTestError.authorizationFailed
        }
        return "credential"
      }
      Issue.record("Expected passkey authentication to fail.")
    } catch {
      #expect(error.stage == expectedStage)
      #expect(error.underlyingError as? PasskeyTestError == passkeyTestError(for: expectedStage))
    }
  }

  private func passkeyTestError(
    for stage: PasskeyAuthenticationFailure.Stage
  ) -> PasskeyTestError {
    switch stage {
    case .preparingFirstFactor:
      .preparationFailed
    case .preparingSecondFactor:
      .secondFactorPreparationFailed
    case .requestingAuthorization:
      .authorizationFailed
    case .attemptingFirstFactor:
      .attemptFailed
    case .attemptingSecondFactor:
      .secondFactorAttemptFailed
    }
  }

  @Test
  func passkeyAuthenticationUsesSecondFactorEndpointsWhenAdvertised() async throws {
    let signIn = SignIn(
      id: "sign_in_123",
      status: .needsSecondFactor,
      supportedSecondFactors: [Factor(strategy: .passkey)]
    )
    let preparedSignIn = SignIn(
      id: signIn.id,
      status: .needsSecondFactor,
      supportedSecondFactors: signIn.secondFactors,
      secondFactorVerification: Verification(
        status: .unverified,
        strategy: .passkey,
        nonce: "{\"challenge\":\"challenge\"}"
      )
    )
    let engine = RecordingEngineClient()
    engine.signInOnReload = preparedSignIn
    Clerk.engineClient = engine

    _ = try await signIn.authenticateWithPasskeyWithFailureContext { _ in "credential" }

    #expect(engine.allInstanceMethods == ["prepareSecondFactor", "attemptSecondFactor"])
    #expect(engine.instanceRoot == "signIn")
    #expect(engine.instanceArgsObject["strategy"] as? String == "passkey")
    #expect(engine.instanceArgsObject["publicKeyCredential"] as? String == "credential")
  }

  @Test(arguments: [
    PasskeyAuthenticationFailure.Stage.preparingSecondFactor,
    .attemptingSecondFactor,
  ])
  func passkeySecondFactorFailureContextIdentifiesFailureStage(
    _ expectedStage: PasskeyAuthenticationFailure.Stage
  ) async {
    let signIn = SignIn(
      id: "sign_in_123",
      status: .needsSecondFactor,
      supportedSecondFactors: [Factor(strategy: .passkey)]
    )
    let engine = RecordingEngineClient()
    engine.signInOnReload = signIn
    if expectedStage == .preparingSecondFactor {
      engine.instanceMethodErrors["prepareSecondFactor"] = PasskeyTestError.secondFactorPreparationFailed
    }
    if expectedStage == .attemptingSecondFactor {
      engine.instanceMethodErrors["attemptSecondFactor"] = PasskeyTestError.secondFactorAttemptFailed
    }
    Clerk.engineClient = engine

    do {
      _ = try await signIn.authenticateWithPasskeyWithFailureContext { _ in "credential" }
      Issue.record("Expected passkey authentication to fail.")
    } catch {
      #expect(error.stage == expectedStage)
      #expect(error.underlyingError as? PasskeyTestError == passkeyTestError(for: expectedStage))
    }
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
