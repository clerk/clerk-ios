//
//  MockDependencyContainer.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

final class MockDependencyContainer: Dependencies {
  let networkingPipeline: NetworkingPipeline
  let keychain: any KeychainStorage
  let appLocalKeychain: any KeychainStorage
  let identityStore: ClerkIdentityStore
  let identityIsInAccessGroup: Bool
  let biometricCredentialKeyManager: any BiometricCredentialKeyManagerProtocol
  let biometricCredentialStore: any BiometricCredentialLocalStoreProtocol
  let configurationManager: ConfigurationManager
  let apiClient: APIClient
  let transport: any APITransport
  let telemetryCollector: any TelemetryCollectorProtocol

  let clientService: ClientServiceProtocol
  let hostedAuthService: HostedAuthServiceProtocol
  let userService: UserServiceProtocol
  let signInService: SignInServiceProtocol
  let signUpService: SignUpServiceProtocol
  let sessionService: SessionServiceProtocol
  let magicLinkService: MagicLinkServiceProtocol
  let passkeyService: PasskeyServiceProtocol
  let biometricCredentialService: BiometricCredentialServiceProtocol
  let organizationService: OrganizationServiceProtocol
  let billingService: BillingServiceProtocol
  let environmentService: EnvironmentServiceProtocol
  let emailAddressService: EmailAddressServiceProtocol
  let phoneNumberService: PhoneNumberServiceProtocol
  let externalAccountService: ExternalAccountServiceProtocol

  let magicLinkStore: MagicLinkStore
  let sessionStatusLogger: SessionStatusLogger

  init(
    apiClient: APIClient,
    transport: (any APITransport)? = nil,
    keychain: (any KeychainStorage)? = nil,
    appLocalKeychain: (any KeychainStorage)? = nil,
    identityKeychain: (any KeychainStorage)? = nil,
    clientKeychain: (any KeychainStorage)? = nil,
    identityIsInAccessGroup: Bool = false,
    biometricCredentialKeyManager: (any BiometricCredentialKeyManagerProtocol)? = nil,
    biometricCredentialStore: (any BiometricCredentialLocalStoreProtocol)? = nil,
    telemetryCollector: (any TelemetryCollectorProtocol)? = nil,
    clientService: (any ClientServiceProtocol)? = nil,
    hostedAuthService: (any HostedAuthServiceProtocol)? = nil,
    userService: (any UserServiceProtocol)? = nil,
    signInService: (any SignInServiceProtocol)? = nil,
    signUpService: (any SignUpServiceProtocol)? = nil,
    sessionService: (any SessionServiceProtocol)? = nil,
    magicLinkService: (any MagicLinkServiceProtocol)? = nil,
    passkeyService: (any PasskeyServiceProtocol)? = nil,
    biometricCredentialService: (any BiometricCredentialServiceProtocol)? = nil,
    organizationService: (any OrganizationServiceProtocol)? = nil,
    billingService: (any BillingServiceProtocol)? = nil,
    environmentService: (any EnvironmentServiceProtocol)? = nil,
    emailAddressService: (any EmailAddressServiceProtocol)? = nil,
    phoneNumberService: (any PhoneNumberServiceProtocol)? = nil,
    externalAccountService: (any ExternalAccountServiceProtocol)? = nil
  ) {
    networkingPipeline = NetworkingPipeline()
    let resolvedKeychain = keychain ?? InMemoryKeychain()
    let resolvedAppLocalKeychain = appLocalKeychain ?? resolvedKeychain
    self.keychain = resolvedKeychain
    self.appLocalKeychain = resolvedAppLocalKeychain
    identityStore = ClerkIdentityStore(keychain: identityKeychain ?? resolvedKeychain, clientKeychain: clientKeychain)
    self.identityIsInAccessGroup = identityIsInAccessGroup
    self.biometricCredentialKeyManager = biometricCredentialKeyManager ?? MockBiometricCredentialKeyManager()
    self.biometricCredentialStore =
      biometricCredentialStore ?? BiometricCredentialLocalStore(keychain: resolvedAppLocalKeychain)
    configurationManager = ConfigurationManager()
    self.apiClient = apiClient
    self.transport = transport ?? apiClient
    self.telemetryCollector = telemetryCollector ?? NoOpTelemetryCollector()
    magicLinkStore = MagicLinkStore(keychain: self.appLocalKeychain)
    sessionStatusLogger = SessionStatusLogger()

    self.clientService = clientService ?? MockClientService()
    self.hostedAuthService = hostedAuthService ?? MockHostedAuthService()
    self.userService = userService ?? MockUserService()
    self.signInService = signInService ?? MockSignInService()
    self.signUpService = signUpService ?? MockSignUpService()
    self.sessionService = sessionService ?? MockSessionService()
    self.magicLinkService = magicLinkService ?? MockMagicLinkService()
    self.passkeyService = passkeyService ?? MockPasskeyService()
    self.biometricCredentialService = biometricCredentialService ?? MockBiometricCredentialService()
    self.organizationService = organizationService ?? MockOrganizationService()
    self.billingService = billingService ?? MockBillingService()
    self.environmentService = environmentService ?? MockEnvironmentService()
    self.emailAddressService = emailAddressService ?? MockEmailAddressService()
    self.phoneNumberService = phoneNumberService ?? MockPhoneNumberService()
    self.externalAccountService = externalAccountService ?? MockExternalAccountService()
  }
}
