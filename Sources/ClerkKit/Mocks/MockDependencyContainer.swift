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
  let keychain: any KeychainStorage
  let appLocalKeychain: any KeychainStorage
  let identityKeychain: any KeychainStorage
  let legacyAppLocalKeychain: (any KeychainStorage)?
  let atomicIdentityStore: (any SharedSessionLocalIdentityStoring)?
  let atomicIdentityIO: SharedSessionLocalIdentityIO?
  let sharedSessionOwnerIdentifier: String?
  let sharedSessionOwnerSlotClearRecovery: SharedSessionOwnerSlotClearRecovery.Context?
  let shouldHydrateProvisionalLegacyClient: Bool
  let biometricCredentialKeyManager: any BiometricCredentialKeyManagerProtocol
  let biometricCredentialStore: any BiometricCredentialLocalStoreProtocol
  let configurationManager: ConfigurationManager
  let telemetryCollector: any TelemetryCollectorProtocol

  let userService: UserServiceProtocol
  let signInService: SignInServiceProtocol
  let sessionService: SessionServiceProtocol
  let passkeyService: PasskeyServiceProtocol
  let organizationService: OrganizationServiceProtocol

  let sessionStatusLogger: SessionStatusLogger

  /// Creates a dependency container with optional custom storage and services.
  ///
  /// - Parameters:
  ///   - keychain: Optional keychain storage (defaults to InMemoryKeychain).
  ///   - biometricCredentialKeyManager: Optional biometric-credential key manager (defaults to MockBiometricCredentialKeyManager).
  ///   - biometricCredentialStore: Optional biometric credential store.
  ///   - telemetryCollector: Optional telemetry collector (defaults to NoOpTelemetryCollector).
  ///   - userService: Optional custom user service (defaults to MockUserService).
  ///   - signInService: Optional custom sign-in service (defaults to MockSignInService).
  ///   - sessionService: Optional custom session service (defaults to MockSessionService).
  ///   - passkeyService: Optional custom passkey service (defaults to MockPasskeyService).
  ///   - organizationService: Optional custom organization service (defaults to MockOrganizationService).
  init(
    keychain: (any KeychainStorage)? = nil,
    appLocalKeychain: (any KeychainStorage)? = nil,
    identityKeychain: (any KeychainStorage)? = nil,
    legacyAppLocalKeychain: (any KeychainStorage)? = nil,
    atomicIdentityStore: (any SharedSessionLocalIdentityStoring)? = nil,
    sharedSessionOwnerIdentifier: String? = Bundle.main.bundleIdentifier,
    sharedSessionOwnerSlotClearRecovery: SharedSessionOwnerSlotClearRecovery.Context? = nil,
    shouldHydrateProvisionalLegacyClient: Bool = false,
    biometricCredentialKeyManager: (any BiometricCredentialKeyManagerProtocol)? = nil,
    biometricCredentialStore: (any BiometricCredentialLocalStoreProtocol)? = nil,
    telemetryCollector: (any TelemetryCollectorProtocol)? = nil,
    userService: (any UserServiceProtocol)? = nil,
    signInService: (any SignInServiceProtocol)? = nil,
    sessionService: (any SessionServiceProtocol)? = nil,
    passkeyService: (any PasskeyServiceProtocol)? = nil,
    organizationService: (any OrganizationServiceProtocol)? = nil
  ) {
    let resolvedKeychain = keychain ?? InMemoryKeychain()
    let resolvedAppLocalKeychain = appLocalKeychain ?? resolvedKeychain
    self.keychain = resolvedKeychain
    self.appLocalKeychain = resolvedAppLocalKeychain
    self.identityKeychain = identityKeychain ?? self.appLocalKeychain
    self.legacyAppLocalKeychain = legacyAppLocalKeychain
    self.atomicIdentityStore = atomicIdentityStore
    atomicIdentityIO = atomicIdentityStore.map {
      SharedSessionLocalIdentityIO(store: $0)
    }
    self.sharedSessionOwnerIdentifier = sharedSessionOwnerIdentifier
    self.sharedSessionOwnerSlotClearRecovery = sharedSessionOwnerSlotClearRecovery
    self.shouldHydrateProvisionalLegacyClient = shouldHydrateProvisionalLegacyClient
    self.biometricCredentialKeyManager = biometricCredentialKeyManager ?? MockBiometricCredentialKeyManager()
    self.biometricCredentialStore =
      biometricCredentialStore ?? BiometricCredentialLocalStore(keychain: resolvedAppLocalKeychain)
    configurationManager = ConfigurationManager()
    self.telemetryCollector = telemetryCollector ?? NoOpTelemetryCollector()
    sessionStatusLogger = SessionStatusLogger()

    // Use custom services if provided, otherwise use mock services
    self.userService = userService ?? MockUserService()
    self.signInService = signInService ?? MockSignInService()
    self.sessionService = sessionService ?? MockSessionService()
    self.passkeyService = passkeyService ?? MockPasskeyService()
    self.organizationService = organizationService ?? MockOrganizationService()
  }
}
