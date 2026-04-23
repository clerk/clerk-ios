@testable import ClerkKit
import Foundation

@MainActor
struct SharedClerkTestSupport {
  private let fixture = ClerkTestFixture()

  func makeSharedClerk(
    userService: MockUserService? = nil,
    signInService: MockSignInService? = nil,
    signUpService: MockSignUpService? = nil,
    sessionService: MockSessionService? = nil,
    passkeyService: MockPasskeyService? = nil,
    organizationService: MockOrganizationService? = nil,
    emailAddressService: MockEmailAddressService? = nil,
    phoneNumberService: MockPhoneNumberService? = nil,
    externalAccountService: MockExternalAccountService? = nil,
    options: Clerk.Options = .init(),
    client: Client? = nil,
    environment: Clerk.Environment? = .mock
  ) throws -> Clerk {
    let clerk = try Clerk(
      dependencies: fixture.makeMockDependencies(
        userService: userService,
        signInService: signInService,
        signUpService: signUpService,
        sessionService: sessionService,
        passkeyService: passkeyService,
        organizationService: organizationService,
        emailAddressService: emailAddressService,
        phoneNumberService: phoneNumberService,
        externalAccountService: externalAccountService,
        options: options
      )
    )
    clerk.client = client
    clerk.environment = environment
    clerk.sessionsByUserId = [:]
    Clerk.installShared(clerk)
    return clerk
  }
}
