@testable import ClerkKit
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

  private func configureServices(signUpService: MockSignUpService) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      signUpService: signUpService
    )
    try! (Clerk.shared.dependencies as! MockDependencyContainer)
      .configurationManager
      .configure(publishableKey: testPublishableKey, options: .init())
  }

  private func configureServices(
    signInService: MockSignInService,
    signUpService: MockSignUpService
  ) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      signInService: signInService,
      signUpService: signUpService
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
      supportedSecondFactors: signIn.supportedSecondFactors,
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
    let service = MockSignInService(prepareFirstFactor: { _, _ in
      throw ClerkClientError(message: "Prepare failed.")
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      signInService: service
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
    let prepareWasCalled = LockIsolated(false)
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
    let service = MockSignInService(prepareFirstFactor: { _, _ in
      prepareWasCalled.setValue(true)
      return signIn
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: SetFailingKeychain(),
      signInService: service
    )

    await #expect(throws: SetFailingKeychain.Failure.self) {
      try await signIn.sendEmailLink()
    }
    #expect(prepareWasCalled.value == false)
  }

  @Test
  func verifyCodeThrowsWhenFirstFactorVerificationStrategyIsNotCodeBased() async throws {
    var signIn = SignIn.mock
    signIn.firstFactorVerification = Verification(
      status: .unverified,
      strategy: .password
    )

    let captured = LockIsolated<(String, SignIn.AttemptFirstFactorParams)?>(nil)
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

    let captured = LockIsolated<(String, SignIn.AttemptFirstFactorParams)?>(nil)
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

    let captured = LockIsolated<SignUp.CreateParams?>(nil)
    let signUpService = MockSignUpService(create: { params in
      captured.setValue(params)
      return .mock
    })

    configureServices(signUpService: signUpService)

    let result = try await signIn.handleTransferFlow(transferable: false)

    switch result {
    case .signIn:
      break
    case .signUp:
      #expect(Bool(false))
    }

    #expect(captured.value == nil)
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

    let createCount = LockIsolated(0)
    let signUpService = MockSignUpService(create: { _ in
      createCount.setValue(createCount.value + 1)
      throw ClerkClientError(message: "Kit FAPI must not run when the JS engine is registered.")
    })

    configureServices(signUpService: signUpService)

    let callbackURL = try #require(URL(string: "myapp://callback"))
    let result = try await signIn.completeEnterpriseSSO(
      callbackURL: callbackURL,
      unsafeMetadata: metadata
    )

    #expect(engine.reloadedNonce == nil)
    #expect(engine.transferredToSignUpMetadata == metadata)
    #expect(createCount.value == 0)

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

    let createCaptured = LockIsolated<SignUp.CreateParams?>(nil)
    let signUpService = MockSignUpService(create: { params in
      createCaptured.setValue(params)
      return .mock
    })

    configureServices(signUpService: signUpService)

    let callbackURL = try #require(URL(string: "myapp://callback"))
    let result = try await signIn.completeEnterpriseSSO(
      callbackURL: callbackURL,
      transferable: false
    )

    #expect(engine.reloadedNonce == nil)
    #expect(createCaptured.value == nil)

    switch result {
    case .signIn(let updatedSignIn):
      #expect(updatedSignIn == reloadedSignIn)
    case .signUp:
      Issue.record("Expected sign-in result.")
    }
  }
}
