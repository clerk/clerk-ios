#if os(iOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct SignInFactorSelectionTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func startingFirstFactorUsesPreferenceOverPreparedVerificationStrategy() {
    var environment = Clerk.Environment.mock
    environment.displayConfig.preferredSignInStrategy = .password
    Clerk.shared.environment = environment

    let signIn = SignIn(
      id: "sign_in_123",
      status: .needsFirstFactor,
      identifier: "user@example.com",
      supportedFirstFactors: [
        .mockPassword,
        .mockEmailCode,
      ],
      firstFactorVerification: Verification(
        status: .unverified,
        strategy: .emailCode
      )
    )

    #expect(signIn.startingFirstFactor?.strategy == .password)
  }

  @Test
  func startingFirstFactorDoesNotMatchMissingIdentifierToMissingSafeIdentifier() {
    var environment = Clerk.Environment.mock
    environment.displayConfig.preferredSignInStrategy = .otp
    Clerk.shared.environment = environment

    let signIn = SignIn(
      id: "sign_in_123",
      status: .needsFirstFactor,
      identifier: nil,
      supportedFirstFactors: [
        Factor(strategy: .password),
        Factor(
          strategy: .emailCode,
          emailAddressId: "ema_123",
          safeIdentifier: "user@example.com"
        ),
      ]
    )

    #expect(signIn.startingFirstFactor?.strategy == .emailCode)
  }

  @Test
  func startingFirstFactorPrefersPasswordWhenPasswordIsPreferred() {
    var environment = Clerk.Environment.mock
    environment.displayConfig.preferredSignInStrategy = .password
    Clerk.shared.environment = environment

    let signIn = SignIn(
      id: "sign_in_123",
      status: .needsFirstFactor,
      identifier: "user@example.com",
      supportedFirstFactors: [
        .mockPassword,
        .mockEmailCode,
        .mockEmailLink,
      ]
    )

    #expect(signIn.startingFirstFactor?.strategy == .password)
  }

  @Test
  func startingFirstFactorChoosesMatchingEmailLinkWhenPasswordIsPreferredAndPasswordIsUnavailable() {
    var environment = Clerk.Environment.mock
    environment.displayConfig.preferredSignInStrategy = .password
    Clerk.shared.environment = environment

    let signIn = SignIn(
      id: "sign_in_123",
      status: .needsFirstFactor,
      identifier: "user@example.com",
      supportedFirstFactors: [
        Factor(
          strategy: .emailLink,
          emailAddressId: "ema_other",
          safeIdentifier: "other@example.com"
        ),
        Factor(
          strategy: .emailCode,
          emailAddressId: "ema_123",
          safeIdentifier: "user@example.com"
        ),
        Factor(
          strategy: .emailLink,
          emailAddressId: "ema_123",
          safeIdentifier: "user@example.com"
        ),
      ]
    )

    let factor = signIn.startingFirstFactor
    #expect(factor?.strategy == .emailLink)
    #expect(factor?.emailAddressId == "ema_123")
  }

  @Test
  func startingFirstFactorDoesNotForceEmailLinkForNonEmailIdentifier() {
    var environment = Clerk.Environment.mock
    environment.displayConfig.preferredSignInStrategy = .otp
    Clerk.shared.environment = environment

    let signIn = SignIn(
      id: "sign_in_123",
      status: .needsFirstFactor,
      identifier: "username_123",
      supportedFirstFactors: [
        .mockPasskey,
        Factor(
          strategy: .emailLink,
          emailAddressId: "ema_123"
        ),
      ]
    )

    #expect(signIn.startingFirstFactor?.strategy == .passkey)
  }

  @Test
  func startingFirstFactorDoesNotUseUnrelatedEmailLinkForUsernameSignIn() {
    var environment = Clerk.Environment.mock
    environment.displayConfig.preferredSignInStrategy = .password
    Clerk.shared.environment = environment

    let signIn = SignIn(
      id: "sign_in_123",
      status: .needsFirstFactor,
      identifier: "username_123",
      supportedFirstFactors: [
        Factor(
          strategy: .emailLink,
          emailAddressId: "ema_123"
        ),
        .mockPassword,
      ]
    )

    #expect(signIn.startingFirstFactor?.strategy == .password)
  }

  @Test
  func resetPasswordFactorPrefersMatchingEmailCodeFactor() {
    let signIn = SignIn(
      id: "sign_in_123",
      status: .needsFirstFactor,
      identifier: "user@example.com",
      supportedFirstFactors: [
        Factor(
          strategy: .resetPasswordPhoneCode,
          phoneNumberId: "phone_123",
          safeIdentifier: "+15555550100"
        ),
        Factor(
          strategy: .resetPasswordEmailCode,
          emailAddressId: "email_other",
          safeIdentifier: "other@example.com"
        ),
        Factor(
          strategy: .resetPasswordEmailCode,
          emailAddressId: "email_123",
          safeIdentifier: "user@example.com"
        ),
      ]
    )

    let factor = signIn.resetPasswordFactor

    #expect(factor?.strategy == .resetPasswordEmailCode)
    #expect(factor?.emailAddressId == "email_123")
  }

  @Test
  func alternativeFirstFactorsKeepEmailCodeAndFilterResetPasswordFactors() {
    let passwordFactor = Factor(strategy: .password)
    let signIn = SignIn(
      id: "sign_in_123",
      status: .needsFirstFactor,
      identifier: "user@example.com",
      supportedFirstFactors: [
        passwordFactor,
        Factor(
          strategy: .emailCode,
          emailAddressId: "email_123",
          safeIdentifier: "user@example.com"
        ),
        Factor(
          strategy: .resetPasswordEmailCode,
          emailAddressId: "email_123",
          safeIdentifier: "user@example.com"
        ),
      ]
    )

    let factors = signIn.alternativeFirstFactors(currentFactor: passwordFactor)

    #expect(factors.map(\.strategy) == [.emailCode])
    #expect(factors.first?.emailAddressId == "email_123")
  }

  @Test
  func alternativeFirstFactorsKeepCodeAlternativesAndFilterNonInlineMethods() {
    let passwordFactor = Factor(strategy: .password)
    let signIn = SignIn(
      id: "sign_in_123",
      status: .needsFirstFactor,
      identifier: "user@example.com",
      supportedFirstFactors: [
        passwordFactor,
        Factor(
          strategy: .emailCode,
          emailAddressId: "email_123",
          safeIdentifier: "user@example.com"
        ),
        Factor(
          strategy: .phoneCode,
          phoneNumberId: "phone_123",
          safeIdentifier: "+15555550100"
        ),
        Factor(
          strategy: .resetPasswordEmailCode,
          emailAddressId: "email_123",
          safeIdentifier: "user@example.com"
        ),
        Factor(strategy: .oauth(.google)),
        Factor(strategy: .enterpriseSSO),
        Factor(strategy: .saml),
      ]
    )

    let strategies = signIn.alternativeFirstFactors(currentFactor: passwordFactor).map(\.strategy)

    #expect(strategies.contains(.emailCode))
    #expect(strategies.contains(.phoneCode))
    #expect(!strategies.contains(.password))
    #expect(!strategies.contains(.resetPasswordEmailCode))
    #expect(!strategies.contains(.oauth(.google)))
    #expect(!strategies.contains(.enterpriseSSO))
    #expect(!strategies.contains(.saml))
  }
}

#endif
