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
  func startingFirstFactorPrefersPreparedVerificationStrategy() {
    let signIn = SignIn(
      id: "sign_in_123",
      status: .needsFirstFactor,
      identifier: "user@example.com",
      supportedFirstFactors: [
        .mockEmailLink,
        .mockEmailCode,
      ],
      firstFactorVerification: Verification(
        status: .unverified,
        strategy: .emailCode
      )
    )

    #expect(signIn.startingFirstFactor?.strategy == .emailCode)
  }

  @Test
  func startingFirstFactorMatchesPreparedVerificationByIdentifierWhenStrategiesRepeat() {
    let signIn = SignIn(
      id: "sign_in_123",
      status: .needsFirstFactor,
      identifier: "second@example.com",
      supportedFirstFactors: [
        Factor(
          strategy: .emailCode,
          emailAddressId: "ema_first",
          safeIdentifier: "first@example.com"
        ),
        Factor(
          strategy: .emailCode,
          emailAddressId: "ema_second",
          safeIdentifier: "second@example.com"
        ),
      ],
      firstFactorVerification: Verification(
        status: .unverified,
        strategy: .emailCode
      )
    )

    #expect(signIn.startingFirstFactor?.emailAddressId == "ema_second")
  }

  @Test
  func startingFirstFactorPrefersEmailLinkForEmailIdentifierWhenPasswordIsPreferred() {
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

    #expect(signIn.startingFirstFactor?.strategy == .emailLink)
  }

  @Test
  func startingFirstFactorChoosesEmailLinkMatchingEmailIdentity() {
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
        Factor(
          strategy: .password,
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
}

#endif
