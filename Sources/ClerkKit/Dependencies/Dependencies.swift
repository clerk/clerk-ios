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

  /// Stable app-local storage for the atomic token and client identity.
  var identityKeychain: any KeychainStorage { get }

  /// The previous bundle-identifier app-local cache used only during adoption.
  var legacyAppLocalKeychain: (any KeychainStorage)? { get }

  /// Atomic app-local identity storage used after shared-session adoption.
  var atomicIdentityStore: (any SharedSessionLocalIdentityStoring)? { get }

  /// Serialized off-main access to the atomic app-local identity storage.
  var atomicIdentityIO: SharedSessionLocalIdentityIO? { get }

  /// Stable owner used for this app's discoverable shared-session slot.
  var sharedSessionOwnerIdentifier: String? { get }

  /// Whether this configuration just adopted legacy shared-session state and may
  /// use the legacy Client as provisional launch UI.
  var shouldHydrateProvisionalLegacyClient: Bool { get }

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

  /// Service for native magic-link operations.
  var magicLinkService: MagicLinkServiceProtocol { get }

  /// Service for passkey operations.
  var passkeyService: PasskeyServiceProtocol { get }

  /// Service for organization-related operations.
  var organizationService: OrganizationServiceProtocol { get }

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
