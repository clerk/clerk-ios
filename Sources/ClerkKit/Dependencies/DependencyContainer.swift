//
//  DependencyContainer.swift
//  Clerk
//

import Foundation

final class DependencyContainer: Dependencies {
  private struct KeychainStorages {
    let shared: any KeychainStorage
    let appLocal: any KeychainStorage
    let identityStore: ClerkIdentityStore
    let identityIsInAccessGroup: Bool
  }

  // MARK: - Core Dependencies

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

  // MARK: - Services

  let userService: UserServiceProtocol
  let passkeyService: PasskeyServiceProtocol
  let biometricCredentialService: BiometricCredentialServiceProtocol
  let organizationService: OrganizationServiceProtocol
  let billingService: BillingServiceProtocol
  let phoneNumberService: PhoneNumberServiceProtocol
  let externalAccountService: ExternalAccountServiceProtocol

  // MARK: - Magic Link

  let magicLinkStore: MagicLinkStore

  // MARK: - Logging

  let sessionStatusLogger: SessionStatusLogger

  // MARK: - Initialization

  /// Creates a new dependency container with the provided configuration.
  ///
  /// - Parameters:
  ///   - publishableKey: The publishable key from Clerk Dashboard.
  ///   - options: Configuration options for the Clerk instance.
  ///
  /// - Throws: `ClerkInitializationError` if the publishable key is invalid or configuration fails.
  @MainActor
  init(
    publishableKey: String,
    options: Clerk.Options,
    runtimeScope: ClerkRuntimeScope,
    probesAccessGroupOverride: Bool? = nil,
    keychainStorageOverride: (any KeychainStorage)? = nil,
    ownerIdentifierProvider: () -> String? = { Bundle.main.bundleIdentifier }
  ) throws {
    configurationManager = ConfigurationManager()

    // Only configure if publishableKey is not empty (temporary containers use empty key)
    // For temporary containers, ConfigurationManager will remain in its default unconfigured state
    if !publishableKey.isEmpty {
      try configurationManager.configure(publishableKey: publishableKey, options: options)
    }

    sessionStatusLogger = SessionStatusLogger()

    // Note: frontendApiUrl is always extracted from the publishable key, even when using a proxy,
    // because it's needed for passkey authentication which requires the original Clerk domain
    // (not the proxy domain) as the relying party identifier.
    let baseURL: URL = if !publishableKey.isEmpty, !configurationManager.frontendApiUrl.isEmpty {
      configurationManager.proxyConfiguration?.baseURL ?? URL(string: configurationManager.frontendApiUrl)!
    } else {
      URL(string: "https://clerk.clerk.dev")!
    }

    networkingPipeline = .clerkDefault(runtimeScope: runtimeScope)
      .appendingRequestMiddleware(options.middleware.request)
      .appendingResponseMiddleware(options.middleware.response)
    let keychainStorages = Self.makeKeychainStorages(
      options: options,
      ownerIdentifier: ownerIdentifierProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
      probesAccessGroup: probesAccessGroupOverride
        ?? (!publishableKey.isEmpty && !EnvironmentDetection.isRunningInTests),
      keychainStorageOverride: keychainStorageOverride
    )
    keychain = keychainStorages.shared
    appLocalKeychain = keychainStorages.appLocal
    identityStore = keychainStorages.identityStore
    identityIsInAccessGroup = keychainStorages.identityIsInAccessGroup
    biometricCredentialKeyManager = BiometricCredentialKeyManager()
    biometricCredentialStore = BiometricCredentialLocalStore(keychain: appLocalKeychain)

    magicLinkStore = MagicLinkStore(keychain: appLocalKeychain)

    let pipeline = networkingPipeline
    apiClient = APIClient(baseURL: baseURL, runtimeScope: runtimeScope) { @Sendable configuration in
      configuration.pipeline = pipeline
      configuration.decoder = .clerkDecoder
      configuration.encoder = .clerkEncoder
      configuration.sessionConfiguration.httpAdditionalHeaders = [
        "Content-Type": "application/x-www-form-urlencoded",
        "clerk-api-version": Clerk.apiVersion,
        "x-ios-sdk-version": Clerk.sdkVersion,
        "x-mobile": Self.mobileHeaderValue,
      ]
    }
    transport = apiClient

    telemetryCollector = Self.createTelemetryCollector(
      publishableKey: configurationManager.publishableKey,
      options: options
    )

    userService = UserService(apiClient: apiClient)
    passkeyService = PasskeyService(apiClient: apiClient)
    biometricCredentialService = BiometricCredentialService(apiClient: apiClient)
    organizationService = OrganizationService(apiClient: apiClient)
    billingService = BillingService(apiClient: apiClient)
    phoneNumberService = PhoneNumberService(apiClient: apiClient)
    externalAccountService = ExternalAccountService(apiClient: apiClient)
  }

  private static func makeKeychainStorage(config: Clerk.Options.KeychainConfig) -> any KeychainStorage {
    makeKeychainStorage(service: config.service, accessGroup: config.normalizedAccessGroup)
  }

  private static func makeKeychainStorages(
    options: Clerk.Options,
    ownerIdentifier: String?,
    probesAccessGroup: Bool,
    keychainStorageOverride: (any KeychainStorage)?
  ) -> KeychainStorages {
    if let keychainStorageOverride {
      return KeychainStorages(
        shared: keychainStorageOverride,
        appLocal: keychainStorageOverride,
        identityStore: ClerkIdentityStore(keychain: keychainStorageOverride),
        identityIsInAccessGroup: false
      )
    }

    let config = options.keychainConfig
    let configured = makeKeychainStorage(config: config)
    guard config.normalizedAccessGroup != nil else {
      return KeychainStorages(
        shared: configured,
        appLocal: configured,
        identityStore: ClerkIdentityStore(keychain: configured),
        identityIsInAccessGroup: false
      )
    }

    // Queries without an access group span every group the app belongs to, so private state
    // needs a service of its own to stay out of the shared group.
    let allGroups = makeKeychainStorage(service: config.service, accessGroup: nil)
    let appLocal = MigratingKeychainStorage(
      primary: makeKeychainStorage(service: "\(ownerIdentifier.nilIfEmpty ?? config.service).clerk.app", accessGroup: nil),
      fallback: allGroups
    )
    let isInGroup = !probesAccessGroup || canAccessAccessGroup(configured)
    return KeychainStorages(
      shared: configured,
      appLocal: appLocal,
      identityStore: ClerkIdentityStore(keychain: isInGroup ? configured : allGroups, clientKeychain: appLocal),
      identityIsInAccessGroup: isInGroup
    )
  }

  private static func canAccessAccessGroup(_ keychain: any KeychainStorage) -> Bool {
    do {
      _ = try keychain.hasItem(forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
      return true
    } catch let error as KeychainError where error.isMissingEntitlement {
      ClerkLogger.error(
        "Clerk cannot access the configured Keychain access group, so authentication stays local to this app. Add the access group to this app's Keychain Sharing entitlement, then relaunch."
      )
      return false
    } catch {
      ClerkLogger.logError(error, message: "Failed to read the configured Keychain access group")
      return true
    }
  }

  private static func makeKeychainStorage(
    service: String,
    accessGroup: String?
  ) -> any KeychainStorage {
    let legacyKeychain = SystemKeychain(
      service: service,
      accessGroup: accessGroup
    )

    #if os(macOS)
    guard accessGroup != nil else {
      return legacyKeychain
    }

    let dataProtectionKeychain = SystemKeychain(
      service: service,
      accessGroup: accessGroup,
      useDataProtectionKeychain: true
    )

    return MigratingKeychainStorage(
      primary: dataProtectionKeychain,
      fallback: legacyKeychain
    )
    #else
    return legacyKeychain
    #endif
  }

  static var mobileHeaderValue: String {
    #if os(macOS) || targetEnvironment(macCatalyst)
    "0"
    #else
    "1"
    #endif
  }

  @MainActor
  private static func createTelemetryCollector(
    publishableKey: String,
    options: Clerk.Options
  ) -> any TelemetryCollectorProtocol {
    guard options.telemetryEnabled else {
      return NoOpTelemetryCollector()
    }

    let telemetryOptions = TelemetryCollectorOptions(
      samplingRate: 1.0,
      maxBufferSize: 5,
      flushInterval: 30.0,
      disableThrottling: false
    )

    let instanceType: InstanceEnvironmentType = publishableKey.starts(with: "pk_live_") ? .production : .development

    return TelemetryCollector(
      options: telemetryOptions,
      networkRequester: URLSession.shared,
      environment: StandaloneTelemetryEnvironment(
        publishableKey: publishableKey,
        instanceType: instanceType,
        telemetryEnabled: options.telemetryEnabled
      )
    )
  }
}
