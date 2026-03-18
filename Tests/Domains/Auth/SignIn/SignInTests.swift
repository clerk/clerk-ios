@testable import ClerkKit
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

  private func configureServices(signUpService: MockSignUpService) {
    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      signUpService: signUpService
    )
  }

  @Test
  func sendEmailCodeUsesSignInServicePrepareFirstFactor() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.PrepareFirstFactorParams)?>(nil)
    let service = MockSignInService(prepareFirstFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.sendEmailCode()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .emailCode)
  }

  @Test
  func sendEmailLinkUsesSignInServicePrepareFirstFactor() async throws {
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
    let captured = LockIsolated<(String, SignIn.PrepareFirstFactorParams)?>(nil)
    let service = MockSignInService(prepareFirstFactor: { id, params in
      captured.setValue((id, params))
      return signIn
    })

    Clerk.shared.dependencies = MockDependencyContainer(
      apiClient: createMockAPIClient(),
      keychain: keychain,
      signInService: service
    )

    _ = try await signIn.sendEmailLink()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .emailLink)
    #expect(params.1.emailAddressId == "ema_123")
    #expect(params.1.redirectUri == Clerk.shared.options.redirectConfig.redirectUrl)
    #expect(params.1.codeChallengeMethod == MagicLinkPKCE.codeChallengeMethod)
    #expect(params.1.codeChallenge?.isEmpty == false)
  }

  @Test
  func sendPhoneCodeUsesSignInServicePrepareFirstFactor() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.PrepareFirstFactorParams)?>(nil)
    let service = MockSignInService(prepareFirstFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.sendPhoneCode()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .phoneCode)
  }

  @Test
  func verifyCodeUsesSignInServiceAttemptFirstFactor() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.AttemptFirstFactorParams)?>(nil)
    let service = MockSignInService(attemptFirstFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.verifyCode("123456")

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .emailCode)
    #expect(params.1.code == "123456")
  }

  @Test
  func verifyCodeUsesExistingFirstFactorVerificationCodeStrategy() async throws {
    var signIn = SignIn.mock
    signIn.firstFactorVerification = Verification(
      status: .unverified,
      strategy: .resetPasswordPhoneCode
    )

    let captured = LockIsolated<(String, SignIn.AttemptFirstFactorParams)?>(nil)
    let service = MockSignInService(attemptFirstFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.verifyCode("123456")

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .resetPasswordPhoneCode)
    #expect(params.1.code == "123456")
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
  func authenticateWithPasswordUsesSignInServiceAttemptFirstFactor() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.AttemptFirstFactorParams)?>(nil)
    let service = MockSignInService(attemptFirstFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.authenticateWithPassword("password123")

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .password)
    #expect(params.1.password == "password123")
  }

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  @Test
  func authenticateWithIdTokenUsesSignInServiceAttemptFirstFactor() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.AttemptFirstFactorParams)?>(nil)
    let service = MockSignInService(attemptFirstFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.authenticateWithIdToken("mock_id_token", provider: .apple)

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .idToken(.apple))
    #expect(params.1.token == "mock_id_token")
  }
  #endif

  @Test
  func sendMfaPhoneCodeUsesSignInServicePrepareSecondFactor() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.PrepareSecondFactorParams)?>(nil)
    let service = MockSignInService(prepareSecondFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.sendMfaPhoneCode()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .phoneCode)
  }

  @Test
  func sendMfaEmailCodeUsesSignInServicePrepareSecondFactor() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.PrepareSecondFactorParams)?>(nil)
    let service = MockSignInService(prepareSecondFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.sendMfaEmailCode()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .emailCode)
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
  func verifyMfaCodeUsesSignInServiceAttemptSecondFactor(
    scenario: MfaVerifyScenario
  ) async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.AttemptSecondFactorParams)?>(nil)
    let service = MockSignInService(attemptSecondFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.verifyMfaCode(scenario.code, type: scenario.mfaType)

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == scenario.expectedStrategy)
    #expect(params.1.code == scenario.code)
  }

  @Test
  func sendResetPasswordEmailCodeUsesSignInServicePrepareFirstFactor() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.PrepareFirstFactorParams)?>(nil)
    let service = MockSignInService(prepareFirstFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.sendResetPasswordEmailCode()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .resetPasswordEmailCode)
  }

  @Test
  func handleTransferFlowCreatesSignUpWhenTransferable() async throws {
    var signIn = SignIn.mock
    signIn.firstFactorVerification = Verification(status: .transferable)

    let captured = LockIsolated<SignUp.CreateParams?>(nil)
    let signUpService = MockSignUpService(create: { params in
      captured.setValue(params)
      return .mock
    })

    configureServices(signUpService: signUpService)

    let result = try await signIn.handleTransferFlow(transferable: true)

    switch result {
    case .signUp:
      break
    case .signIn:
      #expect(Bool(false))
    }

    let params = try #require(captured.value)
    #expect(params.transfer == true)
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
  func sendResetPasswordPhoneCodeUsesSignInServicePrepareFirstFactor() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.PrepareFirstFactorParams)?>(nil)
    let service = MockSignInService(prepareFirstFactor: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.sendResetPasswordPhoneCode()

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.strategy == .resetPasswordPhoneCode)
  }

  @Test
  func resetPasswordUsesSignInServiceResetPassword() async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.ResetPasswordParams)?>(nil)
    let service = MockSignInService(resetPassword: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.resetPassword(newPassword: "newPassword123", signOutOfOtherSessions: true)

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.password == "newPassword123")
    #expect(params.1.signOutOfOtherSessions == true)
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
  func reloadUsesSignInServiceGet(
    scenario: ReloadScenario
  ) async throws {
    let signIn = SignIn.mock
    let captured = LockIsolated<(String, SignIn.GetParams)?>(nil)
    let service = MockSignInService(get: { id, params in
      captured.setValue((id, params))
      return .mock
    })

    configureService(service)

    _ = try await signIn.reload(rotatingTokenNonce: scenario.rotatingTokenNonce)

    let params = try #require(captured.value)
    #expect(params.0 == signIn.id)
    #expect(params.1.rotatingTokenNonce == scenario.rotatingTokenNonce)
  }
}
