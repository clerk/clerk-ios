#if os(iOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct ReverificationFlowTests {
  private let email = Factor(strategy: .emailCode, emailAddressId: "idn_email", safeIdentifier: "sam@clerk.dev")
  private let phone = Factor(strategy: .phoneCode, phoneNumberId: "idn_phone", safeIdentifier: "+15555550100")
  private let password = Factor(strategy: .password)
  private let passkey = Factor(strategy: .passkey)
  private let biometric = Factor(strategy: .biometricCredential)
  private let totp = Factor(strategy: .totp)
  private let backupCode = Factor(strategy: .backupCode)

  init() {
    configureClerkForTesting()
  }

  // MARK: - Factor selection

  @Test
  func usableFirstFactorsDropWhatTheScreensCannotVerify() {
    let factors = ReverificationFlow.usableFactors(
      [
        Factor(strategy: .enterpriseSSO),
        Factor(strategy: .resetPasswordEmailCode, emailAddressId: "idn_email", safeIdentifier: "sam@clerk.dev"),
        Factor(strategy: .emailCode),
        Factor(strategy: .unknown("future_strategy")),
        password,
        email,
        biometric,
      ],
      stage: .firstFactor,
      hasLocalBiometricCredential: false
    )

    #expect(factors == [email, password])
  }

  @Test
  func usableFirstFactorsKeepBiometricsOnlyWithALocalCredential() {
    let factors = ReverificationFlow.usableFactors(
      [password, biometric, passkey],
      stage: .firstFactor,
      hasLocalBiometricCredential: true
    )

    #expect(factors == [passkey, biometric, password])
  }

  @Test
  func usableFactorsPutThePrimaryIdentifierFirst() {
    var primaryEmail = Factor(strategy: .emailCode, emailAddressId: "idn_primary", safeIdentifier: "primary@clerk.dev")
    primaryEmail.primary = true

    let factors = ReverificationFlow.usableFactors(
      [email, primaryEmail],
      stage: .firstFactor,
      hasLocalBiometricCredential: false
    )

    #expect(factors == [primaryEmail, email])
  }

  @Test
  func secondFactorsPreferPasskeyThenAuthenticatorAppThenSMSThenBackupCode() {
    let factors = ReverificationFlow.usableFactors(
      [backupCode, phone, totp, passkey],
      stage: .secondFactor,
      hasLocalBiometricCredential: false
    )

    #expect(factors == [passkey, totp, phone, backupCode])
  }

  @Test
  func startingFirstFactorFollowsThePreferredSignInStrategy() {
    let factors = [email, password]

    #expect(ReverificationFlow.startingFactor(in: factors, stage: .firstFactor, preferredStrategy: .password) == password)
    #expect(ReverificationFlow.startingFactor(in: factors, stage: .firstFactor, preferredStrategy: .otp) == email)
    #expect(ReverificationFlow.startingFactor(in: factors + [passkey], stage: .firstFactor, preferredStrategy: .password) == passkey)
  }

  @Test
  func aCodeScreenSendsACodeUnlessTheLastCodeWentToIt() {
    #expect(ReverificationCodeView.needsCode(sendsCode: true, isFirstRequest: true, lastCodeWasSentHere: false))
    #expect(ReverificationCodeView.needsCode(sendsCode: true, isFirstRequest: false, lastCodeWasSentHere: false))
    #expect(!ReverificationCodeView.needsCode(sendsCode: true, isFirstRequest: false, lastCodeWasSentHere: true))
    #expect(!ReverificationCodeView.needsCode(sendsCode: false, isFirstRequest: true, lastCodeWasSentHere: false))
  }

  // MARK: - Routing

  @Test
  func needsFirstFactorShowsTheStartingFactor() async {
    var environment = Clerk.Environment.mock
    environment.displayConfig.preferredSignInStrategy = .password
    Clerk.shared.environment = environment
    let flow = ReverificationFlow(level: .firstFactor)

    await flow.handle(verification(.needsFirstFactor, first: [email, password]))

    #expect(flow.root == .factor(password, .firstFactor))
  }

  @Test
  func needsSecondFactorReplacesTheFirstFactorStepAndClearsThePath() async {
    Clerk.shared.environment = .mock
    let flow = ReverificationFlow(level: .multiFactor)
    await flow.handle(verification(.needsFirstFactor, first: [email]))
    flow.path = [.alternativeMethods(currentFactor: email, .firstFactor)]

    await flow.handle(verification(.needsSecondFactor, first: [email], second: [backupCode, totp]))

    #expect(flow.root == .factor(totp, .secondFactor))
    #expect(flow.path.isEmpty)
  }

  @Test
  func noUsableFactorShowsGetHelp() async {
    Clerk.shared.environment = .mock
    let flow = ReverificationFlow(level: .firstFactor)

    await flow.handle(verification(.needsFirstFactor, first: [Factor(strategy: .enterpriseSSO)]))

    #expect(flow.root == .getHelp)
  }

  @Test
  func aRepeatedFirstFactorStatusKeepsTheCurrentStep() async {
    Clerk.shared.environment = .mock
    let flow = ReverificationFlow(level: .firstFactor)
    await flow.handle(verification(.needsFirstFactor, first: [email, phone]))
    flow.path = [.factor(phone, .firstFactor)]

    await flow.handle(verification(.needsFirstFactor, first: [email, phone]))

    #expect(flow.root == .factor(email, .firstFactor))
    #expect(flow.path == [.factor(phone, .firstFactor)])
  }

  @Test
  func completeFinishesTheFlow() async {
    let flow = ReverificationFlow(level: .firstFactor)

    await flow.handle(verification(.complete))

    #expect(flow.isComplete)
  }

  @Test
  func anUnknownStatusFails() async {
    let flow = ReverificationFlow(level: .firstFactor)

    await flow.handle(verification(.unknown("needs_protect_check")))

    guard case .failed = flow.phase else {
      Issue.record("Expected the flow to fail, got \(flow.phase)")
      return
    }
  }

  @Test
  func startingWithoutASessionFails() async {
    let flow = ReverificationFlow(level: .firstFactor)

    await flow.start(session: nil, hasLocalBiometricCredential: false)

    guard case .failed = flow.phase else {
      Issue.record("Expected the flow to fail, got \(flow.phase)")
      return
    }
  }

  @Test
  func resetPasswordFactorPrefersEmail() async {
    let resetPhone = Factor(strategy: .resetPasswordPhoneCode, phoneNumberId: "idn_phone", safeIdentifier: "+15555550100")
    let resetEmail = Factor(strategy: .resetPasswordEmailCode, emailAddressId: "idn_email", safeIdentifier: "sam@clerk.dev")
    Clerk.shared.environment = .mock
    let flow = ReverificationFlow(level: .firstFactor)

    await flow.handle(verification(.needsFirstFactor, first: [password, resetPhone, resetEmail]))

    #expect(flow.resetPasswordFactor == resetEmail)
  }

  @Test(arguments: [
    ("form_password_pwned", ReverificationFlow.PasswordResetReason.pwned),
    ("form_password_compromised", .compromised),
  ])
  func aRejectedPasswordThatNeedsAResetNamesWhy(code: String, reason: ReverificationFlow.PasswordResetReason) {
    #expect(ReverificationFlow.PasswordResetReason(ClerkAPIError(code: code)) == reason)
  }

  @Test
  func otherPasswordErrorsDoNotOfferAReset() {
    #expect(ReverificationFlow.PasswordResetReason(ClerkAPIError(code: "form_password_incorrect")) == nil)
    #expect(ReverificationFlow.PasswordResetReason(nil) == nil)
  }

  @Test
  func aRejectedNewPasswordReturnsToTheNewPasswordScreenWithItsError() {
    let flow = ReverificationFlow(level: .firstFactor)
    let reset = Factor(strategy: .resetPasswordEmailCode, emailAddressId: "idn_email", safeIdentifier: "sam@clerk.dev")
    flow.path = [.newPassword(resetFactor: reset, reason: .pwned), .factor(reset, .firstFactor)]

    flow.rejectNewPassword(ClerkAPIError(code: "form_password_length_too_short"))

    #expect(flow.path == [.newPassword(resetFactor: reset, reason: .pwned)])
    #expect((flow.newPasswordError as? ClerkAPIError)?.code == "form_password_length_too_short")
  }

  private func verification(
    _ status: SessionVerification.Status,
    first: [Factor] = [],
    second: [Factor] = []
  ) -> SessionVerification {
    SessionVerification(
      id: "sessver_123",
      status: status,
      level: .multiFactor,
      supportedFirstFactors: first,
      supportedSecondFactors: second
    )
  }
}

extension ReverificationFlow {
  fileprivate var root: Destination? {
    if case .ready(let root) = phase { root } else { nil }
  }
}

#endif
