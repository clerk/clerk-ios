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
}

#endif
