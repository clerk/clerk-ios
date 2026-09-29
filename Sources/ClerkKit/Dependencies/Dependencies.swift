//
//  Dependencies.swift
//  Clerk
//

import Foundation

protocol Dependencies: AnyObject {
  var apiClient: APIClient { get }

  var networkingPipeline: NetworkingPipeline { get }

  var keychain: any KeychainStorage { get }

  /// Keychain storage scoped to this app rather than the configured shared access group.
  var appLocalKeychain: any KeychainStorage { get }

  /// Stable app-local storage for the atomic token and client identity.
  var identityKeychain: any KeychainStorage { get }

  /// The previous bundle-identifier app-local cache used only during adoption.
  var legacyAppLocalKeychain: (any KeychainStorage)? { get }

  var atomicIdentityStore: (any SharedSessionLocalIdentityStoring)? { get }

  /// Serialized off-main access to the atomic app-local identity storage.
  var atomicIdentityIO: SharedSessionLocalIdentityIO? { get }

  var sharedSessionOwnerIdentifier: String? { get }

  /// Bundle-local journal and exact Keychain targets used to finish interrupted identity clears.
  var sharedSessionOwnerSlotClearRecovery: SharedSessionOwnerSlotClearRecovery.Context? { get }

  /// Whether this configuration just adopted legacy shared-session state and may
  /// use the legacy Client as provisional launch UI.
  var shouldHydrateProvisionalLegacyClient: Bool { get }

  var biometricCredentialKeyManager: any BiometricCredentialKeyManagerProtocol { get }

  var biometricCredentialStore: any BiometricCredentialLocalStoreProtocol { get }

  var telemetryCollector: any TelemetryCollectorProtocol { get }

  var clientService: ClientServiceProtocol { get }

  var hostedAuthService: HostedAuthServiceProtocol { get }

  var userService: UserServiceProtocol { get }

  var signInService: SignInServiceProtocol { get }

  var signUpService: SignUpServiceProtocol { get }

  var sessionService: SessionServiceProtocol { get }

  var magicLinkService: MagicLinkServiceProtocol { get }

  var passkeyService: PasskeyServiceProtocol { get }

  var biometricCredentialService: BiometricCredentialServiceProtocol { get }

  var organizationService: OrganizationServiceProtocol { get }

  var billingService: BillingServiceProtocol { get }

  var environmentService: EnvironmentServiceProtocol { get }

  var emailAddressService: EmailAddressServiceProtocol { get }

  var phoneNumberService: PhoneNumberServiceProtocol { get }

  var externalAccountService: ExternalAccountServiceProtocol { get }

  var configurationManager: ConfigurationManager { get }

  var magicLinkStore: MagicLinkStore { get }

  var sessionStatusLogger: SessionStatusLogger { get }
}

extension Dependencies {
  var watchSyncKeychain: any KeychainStorage {
    MigratingKeychainStorage(primary: appLocalKeychain, fallback: keychain)
  }
}
