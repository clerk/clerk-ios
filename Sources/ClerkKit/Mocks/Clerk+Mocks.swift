//
//  Clerk+Mocks.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

@MainActor
package final class MockServicesBuilder {
  package var userService: MockUserService = .init()

  package var passkeyService: MockPasskeyService = .init()

  package var organizationService: MockOrganizationService = .init()

  package var billingService: MockBillingService = .init()

  package var phoneNumberService: MockPhoneNumberService = .init()

  package var externalAccountService: MockExternalAccountService = .init()

  package init() {}
}
