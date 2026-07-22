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
  let appLocalKeychain: any KeychainStorage
  let identityKeychain: any KeychainStorage
  let legacyAppLocalKeychain: (any KeychainStorage)?
  let atomicIdentityStore: (any SharedSessionLocalIdentityStoring)?
  let atomicIdentityIO: SharedSessionLocalIdentityIO?
  let sharedSessionOwnerIdentifier: String?
  let sharedSessionOwnerSlotClearRecovery: SharedSessionOwnerSlotClearRecovery.Context?
  let shouldHydrateProvisionalLegacyClient: Bool
  let configurationManager: ConfigurationManager
  let apiClient: APIClient
  let telemetryCollector: any TelemetryCollectorProtocol

  let clientService: ClientServiceProtocol
  let userService: UserServiceProtocol
  let signInService: SignInServiceProtocol
  let signUpService: SignUpServiceProtocol
  let sessionService: SessionServiceProtocol
  let magicLinkService: MagicLinkServiceProtocol
  let passkeyService: PasskeyServiceProtocol
  let organizationService: OrganizationServiceProtocol
  let environmentService: EnvironmentServiceProtocol
  let emailAddressService: EmailAddressServiceProtocol
  let phoneNumberService: PhoneNumberServiceProtocol
  let externalAccountService: ExternalAccountServiceProtocol

  let magicLinkStore: MagicLinkStore
  let sessionStatusLogger: SessionStatusLogger

  /// Creates a dependency container with the provided API client and optional custom services.
  ///
  /// - Parameters:
  ///   - apiClient: The API client to use (typically a mock for tests/previews).
  ///   - keychain: Optional keychain storage (defaults to InMemoryKeychain).
  ///   - telemetryCollector: Optional telemetry collector (defaults to NoOpTelemetryCollector).
  ///   - clientService: Optional custom client service (defaults to MockClientService with Client.mock).
  ///   - userService: Optional custom user service (defaults to MockUserService).
  ///   - signInService: Optional custom sign-in service (defaults to MockSignInService).
  ///   - signUpService: Optional custom sign-up service (defaults to MockSignUpService).
  ///   - sessionService: Optional custom session service (defaults to MockSessionService).
  ///   - magicLinkService: Optional custom magic-link service (defaults to MockMagicLinkService).
  ///   - passkeyService: Optional custom passkey service (defaults to MockPasskeyService).
  ///   - organizationService: Optional custom organization service (defaults to MockOrganizationService).
  ///   - environmentService: Optional custom environment service (defaults to MockEnvironmentService with Clerk.Environment.mock).
  ///   - emailAddressService: Optional custom email address service (defaults to MockEmailAddressService).
  ///   - phoneNumberService: Optional custom phone number service (defaults to MockPhoneNumberService).
  ///   - externalAccountService: Optional custom external account service (defaults to MockExternalAccountService).
  init(
    apiClient: APIClient,
    keychain: (any KeychainStorage)? = nil,
    appLocalKeychain: (any KeychainStorage)? = nil,
    identityKeychain: (any KeychainStorage)? = nil,
    legacyAppLocalKeychain: (any KeychainStorage)? = nil,
    atomicIdentityStore: (any SharedSessionLocalIdentityStoring)? = nil,
    sharedSessionOwnerIdentifier: String? = Bundle.main.bundleIdentifier,
    sharedSessionOwnerSlotClearRecovery: SharedSessionOwnerSlotClearRecovery.Context? = nil,
    shouldHydrateProvisionalLegacyClient: Bool = false,
    telemetryCollector: (any TelemetryCollectorProtocol)? = nil,
    clientService: (any ClientServiceProtocol)? = nil,
    userService: (any UserServiceProtocol)? = nil,
    signInService: (any SignInServiceProtocol)? = nil,
    signUpService: (any SignUpServiceProtocol)? = nil,
    sessionService: (any SessionServiceProtocol)? = nil,
    magicLinkService: (any MagicLinkServiceProtocol)? = nil,
    passkeyService: (any PasskeyServiceProtocol)? = nil,
    organizationService: (any OrganizationServiceProtocol)? = nil,
    environmentService: (any EnvironmentServiceProtocol)? = nil,
    emailAddressService: (any EmailAddressServiceProtocol)? = nil,
    phoneNumberService: (any PhoneNumberServiceProtocol)? = nil,
    externalAccountService: (any ExternalAccountServiceProtocol)? = nil
  ) {
    networkingPipeline = NetworkingPipeline()
    self.keychain = keychain ?? InMemoryKeychain()
    self.appLocalKeychain = appLocalKeychain ?? self.keychain
    self.identityKeychain = identityKeychain ?? self.appLocalKeychain
    self.legacyAppLocalKeychain = legacyAppLocalKeychain
    self.atomicIdentityStore = atomicIdentityStore
    atomicIdentityIO = atomicIdentityStore.map {
      SharedSessionLocalIdentityIO(store: $0)
    }
    self.sharedSessionOwnerIdentifier = sharedSessionOwnerIdentifier
    self.sharedSessionOwnerSlotClearRecovery = sharedSessionOwnerSlotClearRecovery
    self.shouldHydrateProvisionalLegacyClient = shouldHydrateProvisionalLegacyClient
    configurationManager = ConfigurationManager()
    self.apiClient = apiClient
    self.telemetryCollector = telemetryCollector ?? NoOpTelemetryCollector()
    magicLinkStore = MagicLinkStore(keychain: self.appLocalKeychain)
    sessionStatusLogger = SessionStatusLogger()

    // Use custom services if provided, otherwise use mock services
    self.clientService = clientService ?? MockClientService()
    self.userService = userService ?? MockUserService()
    self.signInService = signInService ?? MockSignInService()
    self.signUpService = signUpService ?? MockSignUpService()
    self.sessionService = sessionService ?? MockSessionService()
    self.magicLinkService = magicLinkService ?? MockMagicLinkService()
    self.passkeyService = passkeyService ?? MockPasskeyService()
    self.organizationService = organizationService ?? MockOrganizationService()
    self.environmentService = environmentService ?? MockEnvironmentService()
    self.emailAddressService = emailAddressService ?? MockEmailAddressService()
    self.phoneNumberService = phoneNumberService ?? MockPhoneNumberService()
    self.externalAccountService = externalAccountService ?? MockExternalAccountService()
  }
}
