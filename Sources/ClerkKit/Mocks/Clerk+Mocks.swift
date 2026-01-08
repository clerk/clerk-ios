//
//  Clerk+Mocks.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Builder for configuring mock services in previews and tests.
///
/// Use this builder to configure custom behaviors for service methods.
/// You can modify handler properties directly on the default services or replace entire services.
///
/// Example:
/// ```swift
/// Clerk.preview { builder in
///   // Modify handler properties directly (recommended)
///   builder.services.signInService.createHandler = { _, _ in
///     try? await Task.sleep(for: .seconds(2))
///     return .mock
///   }
///
///   builder.services.userService.getSessionsHandler = { user in
///     try? await Task.sleep(for: .seconds(1))
///     return [Session.mock, Session.mock2]
///   }
///
///   // Or replace entire services
///   builder.services.clientService = MockClientService {
///     try? await Task.sleep(for: .seconds(1))
///     return Client.mock
///   }
/// }
/// ```
@MainActor
package final class MockServicesBuilder {
  /// Mock client service for customizing `clerk.refreshClient()` behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var clientService: MockClientService = .init()

  /// Mock user service for customizing `User` service methods behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var userService: MockUserService = .init()

  /// Mock sign-in service for customizing sign-in behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var signInService: MockSignInService = .init()

  /// Mock sign-up service for customizing sign-up behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var signUpService: MockSignUpService = .init()

  /// Mock session service for customizing session behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var sessionService: MockSessionService = .init()

  /// Mock passkey service for customizing passkey behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var passkeyService: MockPasskeyService = .init()

  /// Mock organization service for customizing organization behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var organizationService: MockOrganizationService = .init()

  /// Mock environment service for customizing `clerk.refreshEnvironment()` behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var environmentService: MockEnvironmentService = .init()

  /// Mock email address service for customizing email address behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var emailAddressService: MockEmailAddressService = .init()

  /// Mock phone number service for customizing phone number behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var phoneNumberService: MockPhoneNumberService = .init()

  /// Mock external account service for customizing external account behavior.
  /// You can modify handler properties directly or replace the entire service.
  package var externalAccountService: MockExternalAccountService = .init()

  /// Creates a new mock services builder.
  ///
  /// All services are pre-initialized with default mock implementations.
  /// You can modify handler properties directly or replace entire services in the configuration closure.
  package init() {}
}
