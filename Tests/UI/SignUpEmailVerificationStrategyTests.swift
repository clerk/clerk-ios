#if os(iOS)

@testable import ClerkKit
@testable import ClerkKitUI
import Testing

@MainActor
struct SignUpEmailVerificationStrategyTests {
  init() {
    configureClerkForTesting()
  }

  @Test
  func returnsEmailLinkWhenVerificationHasEmailLinkStrategy() {
    let signUp = SignUp(
      id: "sign_up_123",
      status: .missingRequirements,
      requiredFields: [.emailAddress],
      optionalFields: [],
      missingFields: [],
      unverifiedFields: [.emailAddress],
      verifications: ["email_address": Verification(status: .unverified, strategy: .emailLink)],
      emailAddress: "test@example.com",
      passwordEnabled: false,
      abandonAt: .distantFuture
    )

    #expect(signUp.emailVerificationStrategy(prefersEmailLink: false) == .emailLink)
  }

  @Test
  func returnsEmailCodeWhenVerificationHasEmailCodeStrategy() {
    let signUp = SignUp(
      id: "sign_up_123",
      status: .missingRequirements,
      requiredFields: [.emailAddress],
      optionalFields: [],
      missingFields: [],
      unverifiedFields: [.emailAddress],
      verifications: ["email_address": Verification(status: .unverified, strategy: .emailCode)],
      emailAddress: "test@example.com",
      passwordEnabled: false,
      abandonAt: .distantFuture
    )

    #expect(signUp.emailVerificationStrategy(prefersEmailLink: false) == .emailCode)
  }

  @Test
  func liveEmailCodeWinsOverPrefersEmailLink() {
    let signUp = SignUp(
      id: "sign_up_123",
      status: .missingRequirements,
      requiredFields: [.emailAddress],
      optionalFields: [],
      missingFields: [],
      unverifiedFields: [.emailAddress],
      verifications: ["email_address": Verification(status: .unverified, strategy: .emailCode)],
      emailAddress: "test@example.com",
      passwordEnabled: false,
      abandonAt: .distantFuture
    )

    #expect(signUp.emailVerificationStrategy(prefersEmailLink: true) == .emailCode)
  }

  @Test
  func returnsEmailLinkWhenPrefersEmailLink() {
    let signUp = SignUp(
      id: "sign_up_123",
      status: .missingRequirements,
      requiredFields: [.emailAddress],
      optionalFields: [],
      missingFields: [],
      unverifiedFields: [.emailAddress],
      verifications: [:],
      emailAddress: "test@example.com",
      passwordEnabled: false,
      abandonAt: .distantFuture
    )

    #expect(signUp.emailVerificationStrategy(prefersEmailLink: true) == .emailLink)
  }

  @Test
  func defaultsToEmailCodeWhenPrefersEmailLinkIsFalse() {
    let signUp = SignUp(
      id: "sign_up_123",
      status: .missingRequirements,
      requiredFields: [.emailAddress],
      optionalFields: [],
      missingFields: [],
      unverifiedFields: [.emailAddress],
      verifications: [:],
      emailAddress: "test@example.com",
      passwordEnabled: false,
      abandonAt: .distantFuture
    )

    #expect(signUp.emailVerificationStrategy(prefersEmailLink: false) == .emailCode)
  }
}

#endif
