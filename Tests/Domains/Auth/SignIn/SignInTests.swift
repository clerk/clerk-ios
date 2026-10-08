@testable import ClerkKit
import ConcurrencyExtras
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct SignInTests {
  private let transport = FakeTransport.mockDefaults()

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

  private func configureTransport() {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport
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
    transport.stubSignInPrepareFirstFactor { _, _ in
      if expectedStage == .preparingFirstFactor {
        throw PasskeyTestError.preparationFailed
      }
      return .mock
    }
    transport.stubSignInAttemptFirstFactor { _, _ in
      if expectedStage == .attemptingFirstFactor {
        throw PasskeyTestError.attemptFailed
      }
      return .mock
    }

    configureTransport()

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

  @Test
  func publicPasskeyAuthenticationPreservesUnderlyingError() async {
    let signIn = SignIn.mock
    transport.stubSignInPrepareFirstFactor { _, _ in
      throw PasskeyTestError.preparationFailed
    }

    configureTransport()

    await #expect(throws: PasskeyTestError.self) {
      try await signIn.authenticateWithPasskey()
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
    let capturedPrepare = LockIsolated<(String, JSON?)?>(nil)
    let capturedAttempt = LockIsolated<(String, JSON?)?>(nil)
    transport.stubSignInPrepareSecondFactor { id, params in
      capturedPrepare.setValue((id, params))
      return preparedSignIn
    }
    transport.stubSignInAttemptSecondFactor { id, params in
      capturedAttempt.setValue((id, params))
      return preparedSignIn
    }

    configureTransport()

    _ = try await signIn.authenticateWithPasskeyWithFailureContext { _ in "credential" }

    let prepare = try #require(capturedPrepare.value)
    #expect(prepare.0 == signIn.id)
    #expect(prepare.1?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .passkey)
    let attempt = try #require(capturedAttempt.value)
    #expect(attempt.0 == signIn.id)
    #expect(attempt.1?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .passkey)
    #expect(attempt.1?["code"] == nil)
    #expect(attempt.1?["public_key_credential"]?.stringValue == "credential")
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
    transport.stubSignInPrepareSecondFactor { _, _ in
      if expectedStage == .preparingSecondFactor {
        throw PasskeyTestError.secondFactorPreparationFailed
      }
      return signIn
    }
    transport.stubSignInAttemptSecondFactor { _, _ in
      if expectedStage == .attemptingSecondFactor {
        throw PasskeyTestError.secondFactorAttemptFailed
      }
      return signIn
    }

    configureTransport()

    do {
      _ = try await signIn.authenticateWithPasskeyWithFailureContext { _ in "credential" }
      Issue.record("Expected passkey authentication to fail.")
    } catch {
      #expect(error.stage == expectedStage)
      #expect(error.underlyingError as? PasskeyTestError == passkeyTestError(for: expectedStage))
    }
  }

  @Test
  func sendEmailCodePreparesFirstFactor() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stubSignInPrepareFirstFactor { id, params in
      captured.setValue((id, params))
      return .mock
    }

    configureTransport()

    _ = try await signIn.sendEmailCode()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .emailCode)
  }

  @Test
  func sendEmailLinkPreparesFirstFactor() async throws {
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
    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stubSignInPrepareFirstFactor { id, params in
      captured.setValue((id, params))
      return signIn
    }

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport,
      keychain: keychain
    )
    let magicLinkStore = Clerk.shared.dependencies.magicLinkStore

    _ = try await signIn.sendEmailLink()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .emailLink)
    #expect(params.1?["email_address_id"]?.stringValue == "ema_123")
    #expect(params.1?["redirect_uri"]?.stringValue == Clerk.shared.options.redirectConfig.redirectUrl)
    #expect(params.1?["code_challenge_method"]?.stringValue == PKCE.codeChallengeMethod)
    #expect(params.1?["code_challenge"]?.stringValue?.isEmpty == false)

    let pendingFlow = try #require(magicLinkStore.load())
    #expect(pendingFlow.kind == .signIn)
    #expect(pendingFlow.flowId == signIn.id)
    #expect(pendingFlow.codeVerifier.isEmpty == false)
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
    transport.stubSignInPrepareFirstFactor { _, _ in
      throw ClerkClientError(message: "Prepare failed.")
    }

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport,
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
    transport.stubSignInPrepareFirstFactor { _, _ in
      prepareWasCalled.setValue(true)
      return signIn
    }

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport,
      keychain: SetFailingKeychain()
    )

    await #expect(throws: SetFailingKeychain.Failure.self) {
      try await signIn.sendEmailLink()
    }
    #expect(prepareWasCalled.value == false)
  }

  @Test
  func sendMfaEmailLinkPreparesSecondFactor() async throws {
    let keychain = InMemoryKeychain()
    let signIn = SignIn(
      id: "sign_in_123",
      status: .needsClientTrust,
      identifier: "test@example.com",
      supportedSecondFactors: [
        Factor(
          strategy: .emailCode,
          emailAddressId: "ema_123",
          safeIdentifier: "test@example.com"
        ),
        Factor(
          strategy: .emailLink,
          emailAddressId: "ema_123",
          safeIdentifier: "test@example.com"
        ),
      ]
    )
    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stubSignInPrepareSecondFactor { id, params in
      captured.setValue((id, params))
      return signIn
    }

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      transport: transport,
      keychain: keychain
    )
    let magicLinkStore = Clerk.shared.dependencies.magicLinkStore

    _ = try await signIn.sendMfaEmailLink()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .emailLink)
    #expect(params.1?["email_address_id"]?.stringValue == "ema_123")
    #expect(params.1?["redirect_uri"]?.stringValue == Clerk.shared.options.redirectConfig.redirectUrl)
    #expect(params.1?["code_challenge_method"]?.stringValue == PKCE.codeChallengeMethod)
    #expect(params.1?["code_challenge"]?.stringValue?.isEmpty == false)

    let pendingFlow = try #require(magicLinkStore.load())
    #expect(pendingFlow.kind == .signIn)
    #expect(pendingFlow.flowId == signIn.id)
    #expect(pendingFlow.codeVerifier.isEmpty == false)
  }

  @Test
  func sendMfaEmailLinkThrowsWithoutAnEmailLinkSecondFactor() async throws {
    let prepareWasCalled = LockIsolated(false)
    let signIn = SignIn(
      id: "sign_in_123",
      status: .needsClientTrust,
      identifier: "test@example.com",
      supportedSecondFactors: [
        Factor(
          strategy: .emailCode,
          emailAddressId: "ema_123",
          safeIdentifier: "test@example.com"
        ),
      ]
    )
    transport.stubSignInPrepareSecondFactor { _, _ in
      prepareWasCalled.setValue(true)
      return signIn
    }

    configureTransport()

    await #expect(throws: ClerkClientError.self) {
      try await signIn.sendMfaEmailLink()
    }
    #expect(prepareWasCalled.value == false)
  }

  @Test
  func sendPhoneCodePreparesFirstFactor() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stubSignInPrepareFirstFactor { id, params in
      captured.setValue((id, params))
      return .mock
    }

    configureTransport()

    _ = try await signIn.sendPhoneCode()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .phoneCode)
  }

  @Test
  func verifyCodeAttemptsFirstFactor() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stubSignInAttemptFirstFactor { id, params in
      captured.setValue((id, params))
      return .mock
    }

    configureTransport()

    _ = try await signIn.verifyCode("123456")

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .emailCode)
    #expect(params.1?["code"]?.stringValue == "123456")
  }

  @Test
  func verifyCodeUsesExistingFirstFactorVerificationCodeStrategy() async throws {
    var signIn = SignIn.mock
    signIn.firstFactorVerification = Verification(
      status: .unverified,
      strategy: .resetPasswordPhoneCode
    )

    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stubSignInAttemptFirstFactor { id, params in
      captured.setValue((id, params))
      return .mock
    }

    configureTransport()

    _ = try await signIn.verifyCode("123456")

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .resetPasswordPhoneCode)
    #expect(params.1?["code"]?.stringValue == "123456")
  }

  @Test
  func verifyCodeThrowsWhenFirstFactorVerificationStrategyIsNotCodeBased() async throws {
    var signIn = SignIn.mock
    signIn.firstFactorVerification = Verification(
      status: .unverified,
      strategy: .password
    )

    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stubSignInAttemptFirstFactor { id, params in
      captured.setValue((id, params))
      return .mock
    }

    configureTransport()

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

    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stubSignInAttemptFirstFactor { id, params in
      captured.setValue((id, params))
      return .mock
    }

    configureTransport()

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
  func authenticateWithPasswordAttemptsFirstFactor() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stubSignInAttemptFirstFactor { id, params in
      captured.setValue((id, params))
      return .mock
    }

    configureTransport()

    _ = try await signIn.authenticateWithPassword("password123")

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .password)
    #expect(params.1?["password"]?.stringValue == "password123")
  }

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @Test
  func authenticateWithIdTokenAttemptsFirstFactor() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stubSignInAttemptFirstFactor { id, params in
      captured.setValue((id, params))
      return .mock
    }

    configureTransport()

    _ = try await signIn.authenticateWithIdToken("mock_id_token", provider: .apple)

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .idToken(.apple))
    #expect(params.1?["token"]?.stringValue == "mock_id_token")
  }
  #endif

  @Test
  func sendMfaPhoneCodePreparesSecondFactor() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stubSignInPrepareSecondFactor { id, params in
      captured.setValue((id, params))
      return .mock
    }

    configureTransport()

    _ = try await signIn.sendMfaPhoneCode()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .phoneCode)
  }

  @Test
  func sendMfaEmailCodePreparesSecondFactor() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stubSignInPrepareSecondFactor { id, params in
      captured.setValue((id, params))
      return .mock
    }

    configureTransport()

    _ = try await signIn.sendMfaEmailCode()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .emailCode)
  }

  enum MfaVerifyScenario: String, CaseIterable, Codable {
    case phoneCode
    case totp
    case backupCode

    var code: String {
      switch self {
      case .phoneCode:
        "123456"
      case .totp:
        "654321"
      case .backupCode:
        "backup123"
      }
    }

    var mfaType: SignIn.MfaType {
      switch self {
      case .phoneCode:
        .phoneCode
      case .totp:
        .totp
      case .backupCode:
        .backupCode
      }
    }

    var expectedStrategy: FactorStrategy {
      switch self {
      case .phoneCode:
        .phoneCode
      case .totp:
        .totp
      case .backupCode:
        .backupCode
      }
    }
  }

  @Test(arguments: MfaVerifyScenario.allCases)
  func verifyMfaCodeAttemptsSecondFactor(
    scenario: MfaVerifyScenario
  ) async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stubSignInAttemptSecondFactor { id, params in
      captured.setValue((id, params))
      return .mock
    }

    configureTransport()

    _ = try await signIn.verifyMfaCode(scenario.code, type: scenario.mfaType)

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == scenario.expectedStrategy)
    #expect(params.1?["code"]?.stringValue == scenario.code)
  }

  @Test
  func sendResetPasswordEmailCodePreparesFirstFactor() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stubSignInPrepareFirstFactor { id, params in
      captured.setValue((id, params))
      return .mock
    }

    configureTransport()

    _ = try await signIn.sendResetPasswordEmailCode()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .resetPasswordEmailCode)
  }

  @Test
  func handleTransferFlowCreatesSignUpWhenTransferable() async throws {
    let metadata: JSON = ["plan": "pro"]
    var signIn = SignIn.mock
    signIn.firstFactorVerification = Verification(status: .transferable)

    let captured = LockIsolated<JSON?>(nil)
    transport.stubSignUpCreate { params in
      captured.setValue(params)
      return .mock
    }

    configureTransport()

    let result = try await signIn.handleTransferFlow(
      transferable: true,
      unsafeMetadata: metadata
    )

    switch result {
    case .signUp:
      break
    case .signIn:
      #expect(Bool(false))
    }

    let params = try #require(captured.value)
    #expect(params["transfer"]?.boolValue == true)
    #expect(params["unsafe_metadata"] == metadata)
  }

  @Test
  func handleTransferFlowSkipsSignUpWhenNotTransferable() async throws {
    var signIn = SignIn.mock
    signIn.firstFactorVerification = Verification(status: .transferable)

    let captured = LockIsolated<JSON?>(nil)
    transport.stubSignUpCreate { params in
      captured.setValue(params)
      return .mock
    }

    configureTransport()

    let result = try await signIn.handleTransferFlow(transferable: false)

    switch result {
    case .signIn:
      break
    case .signUp:
      #expect(Bool(false))
    }

    #expect(captured.value == nil)
  }

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @Test
  func appleAuthenticationKeepsTheAppleNameWhenItTransfersToSignUp() async throws {
    let metadata: JSON = ["plan": "pro"]
    var transferableSignIn = SignIn.mock
    transferableSignIn.firstFactorVerification = Verification(status: .transferable)

    let attemptParams = LockIsolated<JSON?>(nil)
    transport.stubSignInAttemptFirstFactor { _, params in
      attemptParams.setValue(params)
      return transferableSignIn
    }
    let signUpParams = LockIsolated<JSON?>(nil)
    transport.stubSignUpCreate { params in
      signUpParams.setValue(params)
      return .mock
    }

    configureTransport()

    let result = try await SignIn.mock.completeAppleAuthentication(
      idToken: "apple_token",
      firstName: "Jane",
      lastName: "Doe",
      transferable: true,
      unsafeMetadata: metadata
    )

    guard case .signUp = result else {
      Issue.record("Expected a sign-up result")
      return
    }
    let attempt = try #require(attemptParams.value)
    #expect(attempt["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .idToken(.apple))
    #expect(attempt["token"]?.stringValue == "apple_token")
    let signUp = try #require(signUpParams.value)
    #expect(signUp["transfer"]?.boolValue == true)
    #expect(signUp["first_name"]?.stringValue == "Jane")
    #expect(signUp["last_name"]?.stringValue == "Doe")
    #expect(signUp["unsafe_metadata"] == metadata)
  }

  @Test
  func appleAuthenticationSignsInAnExistingUserWithoutASignUp() async throws {
    transport.stubSignInAttemptFirstFactor { _, _ in .mock }
    let signUpCalled = LockIsolated(false)
    transport.stubSignUpCreate { _ in
      signUpCalled.setValue(true)
      return .mock
    }

    configureTransport()

    let result = try await SignIn.mock.completeAppleAuthentication(
      idToken: "apple_token",
      firstName: "Jane",
      lastName: "Doe",
      transferable: true,
      unsafeMetadata: nil
    )

    guard case .signIn = result else {
      Issue.record("Expected a sign-in result")
      return
    }
    #expect(signUpCalled.value == false)
  }
  #endif

  @Test
  func sendResetPasswordPhoneCodePreparesFirstFactor() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stubSignInPrepareFirstFactor { id, params in
      captured.setValue((id, params))
      return .mock
    }

    configureTransport()

    _ = try await signIn.sendResetPasswordPhoneCode()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1?["strategy"]?.stringValue.map(FactorStrategy.init(rawValue:)) == .resetPasswordPhoneCode)
  }

  @Test
  func resetPasswordPostsNewPassword() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, JSON?)?>(nil)
    transport.stubSignInResetPassword { id, params in
      captured.setValue((id, params))
      return .mock
    }

    configureTransport()

    _ = try await signIn.resetPassword(newPassword: "newPassword123", signOutOfOtherSessions: true)

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1?["password"]?.stringValue == "newPassword123")
    #expect(params.1?["sign_out_of_other_sessions"]?.boolValue == true)
  }

  @Test
  func completeEnterpriseSSOReloadsWithNonce() async throws {
    let signIn = SignIn.mock
    var reloadedSignIn = SignIn.mock
    reloadedSignIn.firstFactorVerification = Verification(status: .verified)

    let captured = LockIsolated<(String, String?)?>(nil)
    transport.stubSignInGet { id, params in
      captured.setValue((id, params))
      return reloadedSignIn
    }

    configureTransport()

    let callbackURL = try #require(URL(string: "myapp://callback?rotating_token_nonce=test_nonce"))
    let result = try await signIn.completeEnterpriseSSO(callbackURL: callbackURL)

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1 == "test_nonce")

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

    let getCaptured = LockIsolated<(String, String?)?>(nil)
    transport.stubSignInGet { id, params in
      getCaptured.setValue((id, params))
      return reloadedSignIn
    }

    let createCaptured = LockIsolated<JSON?>(nil)
    transport.stubSignUpCreate { params in
      createCaptured.setValue(params)
      return .mock
    }

    configureTransport()

    let callbackURL = try #require(URL(string: "myapp://callback"))
    let result = try await signIn.completeEnterpriseSSO(
      callbackURL: callbackURL,
      unsafeMetadata: metadata
    )

    let getParams = try #require(getCaptured.value)
    #expect(getParams.0 == signIn.id)
    #expect(getParams.1 == nil)

    let createParams = try #require(createCaptured.value)
    #expect(createParams["transfer"]?.boolValue == true)
    #expect(createParams["unsafe_metadata"] == metadata)

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

    let getCaptured = LockIsolated<(String, String?)?>(nil)
    transport.stubSignInGet { id, params in
      getCaptured.setValue((id, params))
      return reloadedSignIn
    }

    let createCaptured = LockIsolated<JSON?>(nil)
    transport.stubSignUpCreate { params in
      createCaptured.setValue(params)
      return .mock
    }

    configureTransport()

    let callbackURL = try #require(URL(string: "myapp://callback"))
    let result = try await signIn.completeEnterpriseSSO(
      callbackURL: callbackURL,
      transferable: false
    )

    let getParams = try #require(getCaptured.value)
    #expect(getParams.0 == signIn.id)
    #expect(getParams.1 == nil)
    #expect(createCaptured.value == nil)

    switch result {
    case .signIn(let updatedSignIn):
      #expect(updatedSignIn == reloadedSignIn)
    case .signUp:
      Issue.record("Expected sign-in result.")
    }
  }

  struct ReloadScenario: Codable, Equatable {
    let rotatingTokenNonce: String?
  }

  @Test(
    arguments: [
      ReloadScenario(rotatingTokenNonce: nil),
      ReloadScenario(rotatingTokenNonce: "test_nonce"),
    ]
  )
  func reloadFetchesSignInWithNonce(
    scenario: ReloadScenario
  ) async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, String?)?>(nil)
    transport.stubSignInGet { id, params in
      captured.setValue((id, params))
      return .mock
    }

    configureTransport()

    _ = try await signIn.reload(rotatingTokenNonce: scenario.rotatingTokenNonce)

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1 == scenario.rotatingTokenNonce)
  }
}

extension FakeTransport {
  fileprivate func stubSignInPrepareSecondFactor(_ prepare: @escaping @MainActor (_ signInId: String, _ body: JSON?) async throws -> SignIn) {
    stub(SignInAPI.prepareSecondFactor(signInId: FakeTransport.anyPathSegment, params: .init(strategy: .phoneCode))) { call in
      try await ClientResponse(response: prepare(String(call.path.split(separator: "/")[3]), call.body), client: nil)
    }
  }

  fileprivate func stubSignInAttemptSecondFactor(_ attempt: @escaping @MainActor (_ signInId: String, _ body: JSON?) async throws -> SignIn) {
    stub(SignInAPI.attemptSecondFactor(signInId: FakeTransport.anyPathSegment, params: .init(strategy: .phoneCode))) { call in
      try await ClientResponse(response: attempt(String(call.path.split(separator: "/")[3]), call.body), client: nil)
    }
  }

  fileprivate func stubSignInResetPassword(_ reset: @escaping @MainActor (_ signInId: String, _ body: JSON?) async throws -> SignIn) {
    stub(SignInAPI.resetPassword(signInId: FakeTransport.anyPathSegment, params: .init(password: ""))) { call in
      try await ClientResponse(response: reset(String(call.path.split(separator: "/")[3]), call.body), client: nil)
    }
  }

  fileprivate func stubSignInGet(_ get: @escaping @MainActor (_ signInId: String, _ rotatingTokenNonce: String?) async throws -> SignIn) {
    stub(SignInAPI.get(signInId: FakeTransport.anyPathSegment, params: .init())) { call in
      let nonce = call.query.first { $0.name == "rotating_token_nonce" }?.value
      return try await ClientResponse(response: get(String(call.path.split(separator: "/")[3]), nonce), client: nil)
    }
  }
}
