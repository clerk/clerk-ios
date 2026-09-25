//
//  Dependencies.swift
//  Clerk
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

  /// Keychain storage scoped to this app rather than the configured shared access group.
  var appLocalKeychain: any KeychainStorage { get }

  /// The single persisted record holding the device token and Client.
  var identityStore: ClerkIdentityStore { get }

  /// Whether ``identityStore`` is in the configured access group, where other apps and extensions can read it.
  var identityIsInAccessGroup: Bool { get }

  /// Whether other apps share ``identityStore`` and should be kept in sync with it.
  var sharesIdentity: Bool { get }

  /// Manager for local biometric-credential private keys.
  var biometricCredentialKeyManager: any BiometricCredentialKeyManagerProtocol { get }

  /// Store for local biometric credential metadata.
  var biometricCredentialStore: any BiometricCredentialLocalStoreProtocol { get }

  /// The telemetry collector for development diagnostics.
  var telemetryCollector: any TelemetryCollectorProtocol { get }

  /// Service for client-related operations.
  var clientService: ClientServiceProtocol { get }

  /// Service for hosted authentication operations.
  var hostedAuthService: HostedAuthServiceProtocol { get }

  /// Service for user-related operations.
  var userService: UserServiceProtocol { get }

  /// Service for sign-in operations.
  var signInService: SignInServiceProtocol { get }

  /// Service for sign-up operations.
  var signUpService: SignUpServiceProtocol { get }

  /// Service for session-related operations.
  var sessionService: SessionServiceProtocol { get }

  /// Service for native magic-link operations.
  var magicLinkService: MagicLinkServiceProtocol { get }

  /// Service for passkey operations.
  var passkeyService: PasskeyServiceProtocol { get }

  /// Service for biometric-credential operations.
  var biometricCredentialService: BiometricCredentialServiceProtocol { get }

  /// Service for organization-related operations.
  var organizationService: OrganizationServiceProtocol { get }

  /// Service for billing-related operations.
  var billingService: BillingServiceProtocol { get }

  /// Service for environment-related operations.
  var environmentService: EnvironmentServiceProtocol { get }

  /// Service for email address operations.
  var emailAddressService: EmailAddressServiceProtocol { get }

  /// Service for phone number operations.
  var phoneNumberService: PhoneNumberServiceProtocol { get }

  /// Service for external account operations.
  var externalAccountService: ExternalAccountServiceProtocol { get }

  /// Manages Clerk configuration including API client setup and options.
  var configurationManager: ConfigurationManager { get }

  /// Store for pending native magic-link PKCE state.
  var magicLinkStore: MagicLinkStore { get }

  /// Manages logging of session status changes.
  var sessionStatusLogger: SessionStatusLogger { get }
}

extension Dependencies {
  var watchSyncKeychain: any KeychainStorage {
    MigratingKeychainStorage(primary: appLocalKeychain, fallback: keychain)
  }
}
