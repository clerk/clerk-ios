//
//  DependencyContainer.swift
//  Clerk
//

import Foundation

/// Container that holds all dependencies for the Clerk SDK.
///
/// This class manages the lifecycle of all dependencies and provides them
/// through the `Dependencies` protocol for dependency injection.
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
  let telemetryCollector: any TelemetryCollectorProtocol

  // MARK: - Services

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
    migratesPersistentStateOverride: Bool? = nil,
    keychainStorageOverride: (any KeychainStorage)? = nil,
    ownerIdentifierProvider: () -> String? = { Bundle.main.bundleIdentifier }
  ) throws {
    // Phase 1: Core infrastructure (no dependencies)
    // Create and configure ConfigurationManager first (needed to determine baseURL)
    configurationManager = ConfigurationManager()

    // Only configure if publishableKey is not empty (temporary containers use empty key)
    // For temporary containers, ConfigurationManager will remain in its default unconfigured state
    if !publishableKey.isEmpty {
      try configurationManager.configure(publishableKey: publishableKey, options: options)
    }

    sessionStatusLogger = SessionStatusLogger()

    // Determine baseURL from configured manager (use default if not configured)
    // Note: frontendApiUrl is always extracted from the publishable key, even when using a proxy,
    // because it's needed for passkey authentication which requires the original Clerk domain
    // (not the proxy domain) as the relying party identifier.
    let baseURL: URL = if !publishableKey.isEmpty, !configurationManager.frontendApiUrl.isEmpty {
      configurationManager.proxyConfiguration?.baseURL ?? URL(string: configurationManager.frontendApiUrl)!
    } else {
      // Temporary container fallback
      URL(string: "https://clerk.clerk.dev")!
    }

    networkingPipeline = .clerkDefault(runtimeScope: runtimeScope)
      .appendingRequestMiddleware(options.middleware.request)
      .appendingResponseMiddleware(options.middleware.response)
    let keychainStorages = try Self.makeKeychainStorages(
      options: options,
      frontendApiUrl: configurationManager.frontendApiUrl,
      publishableKey: configurationManager.publishableKey,
      ownerIdentifier: ownerIdentifierProvider()?.trimmingCharacters(in: .whitespacesAndNewlines),
      migratesPersistentState: migratesPersistentStateOverride
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

    // Phase 2: API client (depends on networkingPipeline)
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

    // Phase 3: Telemetry collector (depends on options)
    telemetryCollector = Self.createTelemetryCollector(
      publishableKey: configurationManager.publishableKey,
      options: options
    )

    // Phase 4: Services (depend on apiClient and other dependencies)
    clientService = ClientService(apiClient: apiClient)
    hostedAuthService = HostedAuthService(apiClient: apiClient)
    userService = UserService(apiClient: apiClient)
    signInService = SignInService(apiClient: apiClient)
    signUpService = SignUpService(apiClient: apiClient)
    sessionService = SessionService(apiClient: apiClient)
    magicLinkService = MagicLinkService(apiClient: apiClient)
    passkeyService = PasskeyService(apiClient: apiClient)
    biometricCredentialService = BiometricCredentialService(apiClient: apiClient)
    organizationService = OrganizationService(apiClient: apiClient)
    billingService = BillingService(apiClient: apiClient)
    environmentService = EnvironmentService(apiClient: apiClient)
    emailAddressService = EmailAddressService(apiClient: apiClient)
    phoneNumberService = PhoneNumberService(apiClient: apiClient)
    externalAccountService = ExternalAccountService(apiClient: apiClient)
  }

  private static func makeKeychainStorage(config: Clerk.Options.KeychainConfig) -> any KeychainStorage {
    makeKeychainStorage(service: config.service, accessGroup: config.normalizedAccessGroup)
  }

  private static func makeKeychainStorages(
    options: Clerk.Options,
    frontendApiUrl: String,
    publishableKey: String,
    ownerIdentifier: String?,
    migratesPersistentState: Bool,
    keychainStorageOverride: (any KeychainStorage)?
  ) throws -> KeychainStorages {
    let fingerprint = SharedSessionNamespace(frontendApiUrl: frontendApiUrl, publishableKey: publishableKey).fingerprint
    if let keychainStorageOverride {
      guard !migratesPersistentState else {
        throw ClerkClientError(
          message: "Injected Keychain storage cannot be used with storage migration.",
          localizationBundle: .module
        )
      }
      return KeychainStorages(
        shared: keychainStorageOverride,
        appLocal: keychainStorageOverride,
        identityStore: ClerkIdentityStore(keychain: keychainStorageOverride, instanceFingerprint: fingerprint),
        identityIsInAccessGroup: false
      )
    }

    let config = options.keychainConfig
    let configured = makeKeychainStorage(config: config)
    let storages: KeychainStorages
    let legacyKeychain: any KeychainStorage
    if config.normalizedAccessGroup != nil {
      // Queries without an access group span every group the app belongs to, so private state
      // needs a service of its own to stay out of the shared group.
      let allGroups = makeKeychainStorage(service: config.service, accessGroup: nil)
      let privateKeychain = makeKeychainStorage(
        service: "\(ownerIdentifier.nilIfEmpty ?? config.service).clerk.app",
        accessGroup: nil
      )
      let isInGroup = !migratesPersistentState || canAccessAccessGroup(configured)
      storages = KeychainStorages(
        shared: configured,
        appLocal: MigratingKeychainStorage(primary: privateKeychain, fallback: allGroups),
        identityStore: ClerkIdentityStore(keychain: isInGroup ? configured : allGroups, instanceFingerprint: fingerprint),
        identityIsInAccessGroup: isInGroup
      )
      legacyKeychain = allGroups
    } else {
      storages = KeychainStorages(
        shared: configured,
        appLocal: configured,
        identityStore: ClerkIdentityStore(keychain: configured, instanceFingerprint: fingerprint),
        identityIsInAccessGroup: false
      )
      legacyKeychain = configured
    }

    if migratesPersistentState {
      do {
        try ClerkIdentityMigration(store: storages.identityStore, legacyKeychain: legacyKeychain).migrateIfNeeded()
      } catch {
        ClerkLogger.logError(error, message: "Failed to migrate Clerk Keychain storage from an earlier SDK version")
      }
    }
    return storages
  }

  private static func canAccessAccessGroup(_ keychain: any KeychainStorage) -> Bool {
    do {
      _ = try keychain.hasItem(forKey: ClerkKeychainKey.identity.rawValue)
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

    // Determine instance type from publishable key
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
