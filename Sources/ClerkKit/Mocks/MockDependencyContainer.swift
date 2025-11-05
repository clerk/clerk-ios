//
//  MockDependencyContainer.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// A dependency container for tests and previews that allows injecting custom mock services.
///
/// This container allows replacing service implementations with mocks for
/// testing UI behavior in SwiftUI previews or unit testing without making real API calls.
/// It can be used in both test code (via `@testable import ClerkKit`) and preview code.
final class MockDependencyContainer: Dependencies {
  let networkingPipeline: NetworkingPipeline
  let keychain: any KeychainStorage
  let apiClient: APIClient
  let telemetryCollector: any TelemetryCollectorProtocol

  let clientService: ClientServiceProtocol
  let userService: UserServiceProtocol
  let signInService: SignInServiceProtocol
  let signUpService: SignUpServiceProtocol
  let sessionService: SessionServiceProtocol
  let passkeyService: PasskeyServiceProtocol
  let organizationService: OrganizationServiceProtocol
  let environmentService: EnvironmentServiceProtocol
  let clerkService: ClerkServiceProtocol
  let emailAddressService: EmailAddressServiceProtocol
  let phoneNumberService: PhoneNumberServiceProtocol
  let externalAccountService: ExternalAccountServiceProtocol

  /// Creates a dependency container with the provided API client and optional custom services.
  ///
  /// - Parameters:
  ///   - apiClient: The API client to use (typically a mock for tests/previews).
  ///   - keychain: Optional keychain storage (defaults to InMemoryKeychain).
  ///   - telemetryCollector: Optional telemetry collector (defaults to NoOpTelemetryCollector).
  ///   - clientService: Optional custom client service (defaults to real ClientService with provided apiClient).
  ///   - userService: Optional custom user service (defaults to real UserService with provided apiClient).
  ///   - signInService: Optional custom sign-in service (defaults to real SignInService with provided apiClient).
  ///   - signUpService: Optional custom sign-up service (defaults to real SignUpService with provided apiClient).
  ///   - sessionService: Optional custom session service (defaults to real SessionService with provided apiClient).
  ///   - passkeyService: Optional custom passkey service (defaults to real PasskeyService with provided apiClient).
  ///   - organizationService: Optional custom organization service (defaults to real OrganizationService with provided apiClient).
  ///   - environmentService: Optional custom environment service (defaults to real EnvironmentService with provided apiClient).
  ///   - clerkService: Optional custom clerk service (defaults to real ClerkService with provided apiClient).
  ///   - emailAddressService: Optional custom email address service (defaults to real EmailAddressService with provided apiClient).
  ///   - phoneNumberService: Optional custom phone number service (defaults to real PhoneNumberService with provided apiClient).
  ///   - externalAccountService: Optional custom external account service (defaults to real ExternalAccountService with provided apiClient).
  init(
    apiClient: APIClient,
    keychain: (any KeychainStorage)? = nil,
    telemetryCollector: (any TelemetryCollectorProtocol)? = nil,
    clientService: (any ClientServiceProtocol)? = nil,
    userService: (any UserServiceProtocol)? = nil,
    signInService: (any SignInServiceProtocol)? = nil,
    signUpService: (any SignUpServiceProtocol)? = nil,
    sessionService: (any SessionServiceProtocol)? = nil,
    passkeyService: (any PasskeyServiceProtocol)? = nil,
    organizationService: (any OrganizationServiceProtocol)? = nil,
    environmentService: (any EnvironmentServiceProtocol)? = nil,
    clerkService: (any ClerkServiceProtocol)? = nil,
    emailAddressService: (any EmailAddressServiceProtocol)? = nil,
    phoneNumberService: (any PhoneNumberServiceProtocol)? = nil,
    externalAccountService: (any ExternalAccountServiceProtocol)? = nil
  ) {
    self.networkingPipeline = .clerkDefault
    self.keychain = keychain ?? InMemoryKeychain()
    self.apiClient = apiClient
    self.telemetryCollector = telemetryCollector ?? NoOpTelemetryCollector()

    // Use custom services if provided, otherwise use real services that make HTTP requests
    // This allows tests to intercept HTTP requests through the mock API client
    self.clientService = clientService ?? ClientService(apiClient: apiClient)
    self.userService = userService ?? UserService(apiClient: apiClient)
    self.signInService = signInService ?? SignInService(apiClient: apiClient)
    self.signUpService = signUpService ?? SignUpService(apiClient: apiClient)
    self.sessionService = sessionService ?? SessionService(apiClient: apiClient)
    self.passkeyService = passkeyService ?? PasskeyService(apiClient: apiClient)
    self.organizationService = organizationService ?? OrganizationService(apiClient: apiClient)
    self.environmentService = environmentService ?? EnvironmentService(apiClient: apiClient)
    self.clerkService = clerkService ?? ClerkService(apiClient: apiClient)
    self.emailAddressService = emailAddressService ?? EmailAddressService(apiClient: apiClient)
    self.phoneNumberService = phoneNumberService ?? PhoneNumberService(apiClient: apiClient)
    self.externalAccountService = externalAccountService ?? ExternalAccountService(apiClient: apiClient)
  }
}
