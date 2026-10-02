//
//  Clerk+Mocks.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

@MainActor
package final class MockServicesBuilder {
  package var clientService: MockClientService = .init()

  package var userService: MockUserService = .init()

  package var signInService: MockSignInService = .init()

  package var signUpService: MockSignUpService = .init()

  package var sessionService: MockSessionService = .init()

  package var passkeyService: MockPasskeyService = .init()

  package var organizationService: MockOrganizationService = .init()

  package var billingService: MockBillingService = .init()

  package var environmentService: MockEnvironmentService = .init()

  package var phoneNumberService: MockPhoneNumberService = .init()

  package var externalAccountService: MockExternalAccountService = .init()

  package init() {}
}
