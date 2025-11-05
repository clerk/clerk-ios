//
//  MockDependencyContainer.swift
//  Clerk
//
//  Created by Mike Pitre on 2025-01-27.
//

import Foundation
@testable import ClerkKit

/// A mock dependency container for testing that allows injecting custom dependencies.
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

  /// Creates a mock dependency container with the provided API client and other dependencies.
  ///
  /// - Parameters:
  ///   - apiClient: The API client to use (typically a mock for testing).
  ///   - keychain: Optional keychain storage (defaults to SystemKeychain with default config).
  ///   - telemetryCollector: Optional telemetry collector (defaults to NoOpTelemetryCollector).
  init(
    apiClient: APIClient,
    keychain: (any KeychainStorage)? = nil,
    telemetryCollector: (any TelemetryCollectorProtocol)? = nil
  ) {
    self.networkingPipeline = .clerkDefault
    self.keychain = keychain ?? SystemKeychain(
      service: "com.clerk.test",
      accessGroup: nil
    )
    self.apiClient = apiClient
    self.telemetryCollector = telemetryCollector ?? NoOpTelemetryCollector()

    // Create services with apiClient directly
    self.clientService = ClientService(apiClient: apiClient)
    self.userService = UserService(apiClient: apiClient)
    self.signInService = SignInService(apiClient: apiClient)
    self.signUpService = SignUpService(apiClient: apiClient)
    self.sessionService = SessionService(apiClient: apiClient)
    self.passkeyService = PasskeyService(apiClient: apiClient)
    self.organizationService = OrganizationService(apiClient: apiClient)
    self.environmentService = EnvironmentService(apiClient: apiClient)
    self.clerkService = ClerkService(apiClient: apiClient)
    self.emailAddressService = EmailAddressService(apiClient: apiClient)
    self.phoneNumberService = PhoneNumberService(apiClient: apiClient)
    self.externalAccountService = ExternalAccountService(apiClient: apiClient)
  }
}

