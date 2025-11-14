//
//  Dependencies.swift
//  Clerk
//
//  Created by Mike Pitre on 2025-01-27.
//

import Foundation

/// Protocol defining all dependencies for the Clerk SDK.
///
/// This protocol provides a single interface for accessing all dependencies,
/// making it easy to inject dependencies for testing and maintainability.
protocol Dependencies: AnyObject {
  /// The API client for making network requests.
  var apiClient: APIClient { get }

  /// The networking pipeline for request/response processing.
  var networkingPipeline: NetworkingPipeline { get }

  /// The keychain storage for secure data persistence.
  var keychain: any KeychainStorage { get }

  /// The telemetry collector for development diagnostics.
  var telemetryCollector: any TelemetryCollectorProtocol { get }

  /// Service for client-related operations.
  var clientService: ClientServiceProtocol { get }

  /// Service for user-related operations.
  var userService: UserServiceProtocol { get }

  /// Service for sign-in operations.
  var signInService: SignInServiceProtocol { get }

  /// Service for sign-up operations.
  var signUpService: SignUpServiceProtocol { get }

  /// Service for session-related operations.
  var sessionService: SessionServiceProtocol { get }

  /// Service for passkey operations.
  var passkeyService: PasskeyServiceProtocol { get }

  /// Service for organization-related operations.
  var organizationService: OrganizationServiceProtocol { get }

  /// Service for environment-related operations.
  var environmentService: EnvironmentServiceProtocol { get }

  /// Service for Clerk operations (sign out, set active).
  var clerkService: ClerkServiceProtocol { get }

  /// Service for email address operations.
  var emailAddressService: EmailAddressServiceProtocol { get }

  /// Service for phone number operations.
  var phoneNumberService: PhoneNumberServiceProtocol { get }

  /// Service for external account operations.
  var externalAccountService: ExternalAccountServiceProtocol { get }

  /// Manages Clerk configuration including API client setup and options.
  var configurationManager: ConfigurationManager { get }

  /// Manages logging of session status changes.
  var sessionStatusLogger: SessionStatusLogger { get }
}
