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
  let cacheWrites: KeychainWriteQueue
  let identityIsInAccessGroup: Bool
  let biometricCredentialKeyManager: any BiometricCredentialKeyManagerProtocol
  let biometricCredentialStore: any BiometricCredentialLocalStoreProtocol
  let configurationManager: ConfigurationManager
  let apiClient: APIClient
  let transport: any APITransport
  let telemetryCollector: any TelemetryCollectorProtocol

  let magicLinkStore: MagicLinkStore
  let sessionStatusLogger: SessionStatusLogger

  @MainActor
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
    telemetryCollector: (any TelemetryCollectorProtocol)? = nil
  ) {
    networkingPipeline = NetworkingPipeline()
    let resolvedKeychain = keychain ?? InMemoryKeychain()
    let resolvedAppLocalKeychain = appLocalKeychain ?? resolvedKeychain
    self.keychain = resolvedKeychain
    self.appLocalKeychain = resolvedAppLocalKeychain
    let cacheWrites = KeychainWriteQueue()
    self.cacheWrites = cacheWrites
    identityStore = ClerkIdentityStore(
      keychain: identityKeychain ?? resolvedKeychain,
      clientKeychain: clientKeychain,
      cacheWrites: cacheWrites
    )
    self.identityIsInAccessGroup = identityIsInAccessGroup
    self.biometricCredentialKeyManager = biometricCredentialKeyManager ?? MockBiometricCredentialKeyManager()
    self.biometricCredentialStore =
      biometricCredentialStore ?? BiometricCredentialLocalStore(keychain: resolvedAppLocalKeychain)
    configurationManager = ConfigurationManager()
    self.apiClient = apiClient
    self.transport = transport ?? FakeTransport.mockDefaults()
    self.telemetryCollector = telemetryCollector ?? NoOpTelemetryCollector()
    magicLinkStore = MagicLinkStore(keychain: self.appLocalKeychain)
    sessionStatusLogger = SessionStatusLogger()
  }
}
