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

    #expect(signUp.emailVerificationStrategy == .emailLink)
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

    #expect(signUp.emailVerificationStrategy == .emailCode)
  }

  @Test
  func returnsEmailLinkWhenEnvironmentHasEmailLinkVerification() {
    var environment = Clerk.Environment.mock
    environment.userSettings.attributes["email_address"]?.verifications = ["email_link"]
    Clerk.shared.environment = environment

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

    #expect(signUp.emailVerificationStrategy == .emailLink)
  }

  @Test
  func defaultsToEmailCodeWhenNoVerificationInfo() {
    Clerk.shared.environment = .mock

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

    #expect(signUp.emailVerificationStrategy == .emailCode)
  }
}

#endif
