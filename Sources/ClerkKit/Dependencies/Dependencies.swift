//
//  Dependencies.swift
//  Clerk
//

import Foundation

protocol Dependencies: AnyObject {
  var apiClient: APIClient { get }

  var transport: any APITransport { get }

  var networkingPipeline: NetworkingPipeline { get }

  var keychain: any KeychainStorage { get }

  /// Keychain storage scoped to this app rather than the configured shared access group.
  var appLocalKeychain: any KeychainStorage { get }

  var identityStore: ClerkIdentityStore { get }

  var identityIsInAccessGroup: Bool { get }

  var biometricCredentialKeyManager: any BiometricCredentialKeyManagerProtocol { get }

  var biometricCredentialStore: any BiometricCredentialLocalStoreProtocol { get }

  var telemetryCollector: any TelemetryCollectorProtocol { get }

  var userService: UserServiceProtocol { get }

  var signInService: SignInServiceProtocol { get }

  var signUpService: SignUpServiceProtocol { get }

  var sessionService: SessionServiceProtocol { get }

  var passkeyService: PasskeyServiceProtocol { get }

  var biometricCredentialService: BiometricCredentialServiceProtocol { get }

  var organizationService: OrganizationServiceProtocol { get }

  var billingService: BillingServiceProtocol { get }

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
