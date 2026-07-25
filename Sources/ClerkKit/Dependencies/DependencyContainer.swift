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
  enum PersistenceFailureBehavior: Equatable {
    case failConfiguration
    case useVolatileStorage
  }

  struct KeychainMigrationAccessGroups: Equatable {
    let configuredAppLocal: [String]
    let identity: [String]
  }

  private struct KeychainStorages {
    let shared: any KeychainStorage
    let appLocal: any KeychainStorage
    let identity: any KeychainStorage
    let legacyAppLocal: (any KeychainStorage)?
    let localIdentityStore: (any SharedSessionLocalIdentityStoring)?
    let shouldHydrateProvisionalLegacyClient: Bool
  }

  private struct KeychainBootstrap {
    let storages: KeychainStorages
    let identityPersistenceCapability: IdentityPersistenceCapability
    let bootstrapFailure: PersistenceFailureKind?
  }

  // MARK: - Core Dependencies

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
  let identityPersistenceCapability: IdentityPersistenceCapability
  let identityPersistenceBootstrapFailure: PersistenceFailureKind?
  private let persistentAdoptionEnabled: Bool
  let configurationManager: ConfigurationManager
  let apiClient: APIClient
  let telemetryCollector: any TelemetryCollectorProtocol

  // MARK: - Services

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
    deferSharedSessionAdoption: Bool = false,
    persistentAdoptionEnabledOverride: Bool? = nil,
    keychainStorageOverride: (any KeychainStorage)? = nil,
    persistenceFailureBehavior: PersistenceFailureBehavior = .failConfiguration,
    forceVolatileIdentityPersistence: PersistenceFailureKind? = nil,
    ownerIdentifierProvider: () -> String? = { Bundle.main.bundleIdentifier },
    ownerSlotClearRecoveryProvider: (
      @MainActor (ConfigurationManager, String?) -> SharedSessionOwnerSlotClearRecovery.Context?
    )? = nil
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
    sharedSessionOwnerIdentifier = ownerIdentifierProvider()?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    try Self.validateKeychainConfiguration(
      options: options,
      ownerIdentifier: sharedSessionOwnerIdentifier
    )
    let appLocalAccessGroup = try AppLocalKeychainAccessGroup.resolve(
      config: options.keychainConfig,
      ownerIdentifier: sharedSessionOwnerIdentifier,
      requiresIsolation: options.sharedSessionSync != nil
    )
    persistentAdoptionEnabled = persistentAdoptionEnabledOverride
      ?? (!publishableKey.isEmpty && !EnvironmentDetection.isRunningInTests)
    sharedSessionOwnerSlotClearRecovery = if persistentAdoptionEnabled {
      if let ownerSlotClearRecoveryProvider {
        ownerSlotClearRecoveryProvider(
          configurationManager,
          sharedSessionOwnerIdentifier
        )
      } else {
        Self.makeOwnerSlotClearRecovery(
          configuration: configurationManager,
          ownerIdentifier: sharedSessionOwnerIdentifier,
          appLocalAccessGroup: appLocalAccessGroup
        )
      }
    } else {
      nil
    }
    let keychainBootstrap = if let forceVolatileIdentityPersistence {
      KeychainBootstrap(
        storages: Self.makeVolatileKeychainStorages(),
        identityPersistenceCapability: .volatile(
          forceVolatileIdentityPersistence
        ),
        bootstrapFailure: nil
      )
    } else {
      try Self.bootstrapKeychainStorages(
        configuration: configurationManager,
        options: options,
        ownerIdentifier: sharedSessionOwnerIdentifier,
        appLocalAccessGroup: appLocalAccessGroup,
        usePersistentAdoptionState: persistentAdoptionEnabled,
        performPersistentAdoption: !deferSharedSessionAdoption,
        keychainStorageOverride: keychainStorageOverride,
        failureBehavior: persistenceFailureBehavior
      )
    }
    let keychainStorages = keychainBootstrap.storages
    identityPersistenceCapability =
      keychainBootstrap.identityPersistenceCapability
    identityPersistenceBootstrapFailure =
      keychainBootstrap.bootstrapFailure
    keychain = keychainStorages.shared
    appLocalKeychain = keychainStorages.appLocal
    identityKeychain = keychainStorages.identity
    legacyAppLocalKeychain = keychainStorages.legacyAppLocal
    atomicIdentityStore = keychainStorages.localIdentityStore
    shouldHydrateProvisionalLegacyClient = keychainStorages.shouldHydrateProvisionalLegacyClient
    atomicIdentityIO = keychainStorages.localIdentityStore.map {
      SharedSessionLocalIdentityIO(store: $0)
    }

    magicLinkStore = MagicLinkStore(keychain: appLocalKeychain)

    apiClient = Self.makeAPIClient(
      baseURL: baseURL,
      runtimeScope: runtimeScope,
      networkingPipeline: networkingPipeline
    )

    // Phase 3: Telemetry collector (depends on options)
    telemetryCollector = Self.createTelemetryCollector(
      publishableKey: configurationManager.publishableKey,
      options: options
    )

    // Phase 4: Services (depend on apiClient and other dependencies)
    clientService = ClientService(apiClient: apiClient)
    userService = UserService(apiClient: apiClient)
    signInService = SignInService(apiClient: apiClient)
    signUpService = SignUpService(apiClient: apiClient)
    sessionService = SessionService(apiClient: apiClient)
    magicLinkService = MagicLinkService(apiClient: apiClient)
    passkeyService = PasskeyService(apiClient: apiClient)
    organizationService = OrganizationService(apiClient: apiClient)
    environmentService = EnvironmentService(apiClient: apiClient)
    emailAddressService = EmailAddressService(apiClient: apiClient)
    phoneNumberService = PhoneNumberService(apiClient: apiClient)
    externalAccountService = ExternalAccountService(apiClient: apiClient)
  }
}

extension DependencyContainer {
  static func keychainMigrationAccessGroups(
    config: Clerk.Options.KeychainConfig
  ) -> KeychainMigrationAccessGroups {
    KeychainMigrationAccessGroups(
      configuredAppLocal: [],
      identity: config.normalizedAccessGroup.map { [$0] } ?? []
    )
  }

  private static func makeAPIClient(
    baseURL: URL,
    runtimeScope: ClerkRuntimeScope,
    networkingPipeline: NetworkingPipeline
  ) -> APIClient {
    APIClient(
      baseURL: baseURL,
      runtimeScope: runtimeScope
    ) { @Sendable configuration in
      configuration.pipeline = networkingPipeline
      configuration.decoder = .clerkDecoder
      configuration.encoder = .clerkEncoder
      configuration.sessionConfiguration.httpAdditionalHeaders = [
        "Content-Type": "application/x-www-form-urlencoded",
        "clerk-api-version": Clerk.apiVersion,
        "x-ios-sdk-version": Clerk.sdkVersion,
        "x-mobile": "1",
      ]
    }
  }

  private static func makeKeychainStorage(config: Clerk.Options.KeychainConfig) -> any KeychainStorage {
    makeKeychainStorage(service: config.service, accessGroup: config.normalizedAccessGroup)
  }

  @MainActor
  private static func bootstrapKeychainStorages(
    configuration: ConfigurationManager,
    options: Clerk.Options,
    ownerIdentifier: String?,
    appLocalAccessGroup: String?,
    usePersistentAdoptionState: Bool,
    performPersistentAdoption: Bool,
    keychainStorageOverride: (any KeychainStorage)?,
    failureBehavior: PersistenceFailureBehavior
  ) throws -> KeychainBootstrap {
    do {
      return try KeychainBootstrap(
        storages: makeKeychainStorages(
          options: options,
          frontendApiUrl: configuration.frontendApiUrl,
          publishableKey: configuration.publishableKey,
          ownerIdentifier: ownerIdentifier,
          appLocalAccessGroup: appLocalAccessGroup,
          usePersistentAdoptionState: usePersistentAdoptionState,
          performPersistentAdoption: performPersistentAdoption,
          keychainStorageOverride: keychainStorageOverride
        ),
        identityPersistenceCapability: .durable,
        bootstrapFailure: nil
      )
    } catch {
      let failure = PersistenceFailureKind.classify(error)
      guard failureBehavior == .useVolatileStorage,
            keychainStorageOverride == nil
      else {
        throw error
      }
      if !failure.permitsVolatileIdentityFallback {
        return try KeychainBootstrap(
          storages: makeKeychainStorages(
            options: options,
            frontendApiUrl: configuration.frontendApiUrl,
            publishableKey: configuration.publishableKey,
            ownerIdentifier: ownerIdentifier,
            appLocalAccessGroup: appLocalAccessGroup,
            usePersistentAdoptionState: false,
            performPersistentAdoption: false,
            keychainStorageOverride: nil
          ),
          identityPersistenceCapability: .durable,
          bootstrapFailure: failure
        )
      }
      ClerkLogger.logError(
        error,
        message: "Durable Clerk identity storage is unavailable. Continuing with an isolated in-memory identity for this process."
      )
      return KeychainBootstrap(
        storages: makeVolatileKeychainStorages(),
        identityPersistenceCapability: .volatile(failure),
        bootstrapFailure: nil
      )
    }
  }

  private static func validateKeychainConfiguration(
    options: Clerk.Options,
    ownerIdentifier: String?
  ) throws {
    guard options.sharedSessionSync != nil else { return }
    guard options.keychainConfig.normalizedAccessGroup != nil else {
      throw ClerkClientError(
        message: "Shared session sync requires a nonempty Keychain access group."
      )
    }
    guard ownerIdentifier?.isEmpty == false else {
      throw ClerkClientError(
        message: "Shared session sync requires a nonempty application bundle identifier."
      )
    }
  }

  private static func makeVolatileKeychainStorages() -> KeychainStorages {
    let keychain = InMemoryKeychain()
    return KeychainStorages(
      shared: keychain,
      appLocal: keychain,
      identity: keychain,
      legacyAppLocal: nil,
      localIdentityStore: SharedSessionLocalIdentityStore(keychain: keychain),
      shouldHydrateProvisionalLegacyClient: false
    )
  }

  private static func makeKeychainStorages(
    options: Clerk.Options,
    frontendApiUrl: String,
    publishableKey: String,
    ownerIdentifier: String?,
    appLocalAccessGroup: String?,
    usePersistentAdoptionState: Bool,
    performPersistentAdoption: Bool,
    keychainStorageOverride: (any KeychainStorage)?
  ) throws -> KeychainStorages {
    if let keychainStorageOverride {
      guard options.sharedSessionSync == nil,
            !usePersistentAdoptionState
      else {
        throw ClerkClientError(
          message: "Injected Keychain storage cannot be used with persistent shared-session adoption."
        )
      }

      return KeychainStorages(
        shared: keychainStorageOverride,
        appLocal: keychainStorageOverride,
        identity: keychainStorageOverride,
        legacyAppLocal: nil,
        localIdentityStore: nil,
        shouldHydrateProvisionalLegacyClient: false
      )
    }

    let config = options.keychainConfig
    let shared = makeKeychainStorage(config: config)
    let syncEnabled = options.sharedSessionSync != nil
    let migrationAccessGroups = keychainMigrationAccessGroups(
      config: config
    )

    let configuredAppLocal: any KeychainStorage = if let appLocalAccessGroup {
      ApplicationKeychainStorage.make(
        service: config.service,
        accessGroup: appLocalAccessGroup,
        migrateLegacyUnscopedItems: true,
        legacyAccessGroups: migrationAccessGroups.configuredAppLocal
      )
    } else {
      shared
    }
    let previousAppLocal = makePreviousAppLocalKeychain(
      configuredService: config.service,
      bundleIdentifier: ownerIdentifier,
      configuredAppLocal: configuredAppLocal,
      appLocalAccessGroup: appLocalAccessGroup,
      legacyAccessGroups: migrationAccessGroups.identity
    )
    let namespace = SharedSessionNamespace(
      frontendApiUrl: frontendApiUrl,
      publishableKey: publishableKey
    )
    let stableIdentityService = stableIdentityService(
      configuredService: config.service,
      instanceFingerprint: namespace.fingerprint,
      ownerIdentifier: ownerIdentifier
    )
    let stableIdentity: any KeychainStorage = if let appLocalAccessGroup {
      ApplicationKeychainStorage.make(
        service: stableIdentityService,
        accessGroup: appLocalAccessGroup,
        migrateLegacyUnscopedItems: true,
        legacyAccessGroups: migrationAccessGroups.identity
      )
    } else {
      makeKeychainStorage(
        service: stableIdentityService,
        accessGroup: nil
      )
    }

    if syncEnabled {
      var shouldHydrateProvisionalLegacyClient = false
      if usePersistentAdoptionState, performPersistentAdoption {
        let wasAdopted = try SharedSessionSyncAdoption.isAdopted(in: stableIdentity)
        try SharedSessionSyncAdoption(
          destinationIdentity: stableIdentity,
          destinationPrivate: configuredAppLocal,
          configuredAppLocalIdentity: configuredAppLocal,
          previousAppLocalIdentity: previousAppLocal,
          legacyShared: shared
        ).migrateIfNeeded()
        shouldHydrateProvisionalLegacyClient = !wasAdopted
      }
      return KeychainStorages(
        shared: shared,
        appLocal: configuredAppLocal,
        identity: stableIdentity,
        legacyAppLocal: previousAppLocal,
        localIdentityStore: SharedSessionLocalIdentityStore(keychain: stableIdentity),
        shouldHydrateProvisionalLegacyClient: shouldHydrateProvisionalLegacyClient
      )
    }

    let wasAdopted = usePersistentAdoptionState
      ? try SharedSessionSyncAdoption.isAdopted(in: stableIdentity)
      : false
    let adoptedIdentityStore = wasAdopted
      ? SharedSessionLocalIdentityStore(keychain: stableIdentity)
      : nil
    return KeychainStorages(
      shared: shared,
      appLocal: wasAdopted ? configuredAppLocal : shared,
      identity: wasAdopted ? stableIdentity : shared,
      legacyAppLocal: previousAppLocal,
      localIdentityStore: adoptedIdentityStore,
      shouldHydrateProvisionalLegacyClient: false
    )
  }

  @MainActor
  func performDeferredSharedSessionAdoptionIfNeeded() throws -> Bool {
    guard persistentAdoptionEnabled,
          configurationManager.options.sharedSessionSync != nil
    else {
      return false
    }

    let wasAdopted = try SharedSessionSyncAdoption.isAdopted(
      in: identityKeychain
    )
    try SharedSessionSyncAdoption(
      destinationIdentity: identityKeychain,
      destinationPrivate: appLocalKeychain,
      configuredAppLocalIdentity: appLocalKeychain,
      previousAppLocalIdentity: legacyAppLocalKeychain,
      legacyShared: keychain
    ).migrateIfNeeded()
    return !wasAdopted
  }

  /// Removes an interrupted shared-session publication before installing a non-shared runtime.
  @MainActor
  func discardPendingPublicationWhenSharedSyncDisabled() throws {
    guard configurationManager.options.sharedSessionSync == nil else { return }
    try atomicIdentityStore?.clearPendingPublication()
  }

  @MainActor
  func markSharedSessionAdoptedWithoutMigratingCredentialsIfNeeded() throws {
    guard persistentAdoptionEnabled,
          configurationManager.options.sharedSessionSync != nil
    else {
      return
    }

    try SharedSessionSyncAdoption(
      destinationIdentity: identityKeychain,
      destinationPrivate: appLocalKeychain,
      configuredAppLocalIdentity: appLocalKeychain,
      previousAppLocalIdentity: legacyAppLocalKeychain,
      legacyShared: keychain
    ).markAdoptedWithoutMigratingCredentials()
  }

  private static func makePreviousAppLocalKeychain(
    configuredService: String,
    bundleIdentifier: String?,
    configuredAppLocal: any KeychainStorage,
    appLocalAccessGroup: String?,
    legacyAccessGroups: [String]
  ) -> (any KeychainStorage)? {
    guard let bundleIdentifier, !bundleIdentifier.isEmpty else {
      return nil
    }
    guard bundleIdentifier != configuredService else {
      return configuredAppLocal
    }
    if let appLocalAccessGroup {
      return ApplicationKeychainStorage.make(
        service: bundleIdentifier,
        accessGroup: appLocalAccessGroup,
        migrateLegacyUnscopedItems: true,
        legacyAccessGroups: legacyAccessGroups
      )
    }
    return makeKeychainStorage(service: bundleIdentifier, accessGroup: nil)
  }

  static func stableIdentityService(
    configuredService: String,
    instanceFingerprint: String,
    ownerIdentifier: String?
  ) -> String {
    let owner = if let ownerIdentifier, !ownerIdentifier.isEmpty {
      ownerIdentifier
    } else {
      configuredService
    }
    return "\(owner).clerk.identity.v2.\(instanceFingerprint)"
  }

  static func makeKeychainStorage(
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

extension DependencyContainer {
  @MainActor
  static func makeOwnerSlotClearRecovery(
    configuration: ConfigurationManager,
    ownerIdentifier: String?,
    appLocalAccessGroup: String? = nil
  ) -> SharedSessionOwnerSlotClearRecovery.Context? {
    let namespace = SharedSessionNamespace(
      frontendApiUrl: configuration.frontendApiUrl,
      publishableKey: configuration.publishableKey
    )
    let intent: SharedSessionOwnerSlotClearRecovery.Intent? = if configuration.options.sharedSessionSync != nil,
                                                                 let ownerIdentifier,
                                                                 !ownerIdentifier.isEmpty,
                                                                 let accessGroup = configuration.options.keychainConfig.normalizedAccessGroup
    {
      SharedSessionOwnerSlotClearRecovery.Intent(
        localIdentityService: stableIdentityService(
          configuredService: configuration.options.keychainConfig.service,
          instanceFingerprint: namespace.fingerprint,
          ownerIdentifier: ownerIdentifier
        ),
        localIdentityAccessGroup: appLocalAccessGroup,
        slotService: SharedSessionOwnerSlotStore.service(
          configuredService: configuration.options.keychainConfig.service,
          instanceFingerprint: namespace.fingerprint
        ),
        slotAccessGroup: accessGroup,
        slotAccount: SharedSessionOwnerSlotStore.account(
          instanceFingerprint: namespace.fingerprint,
          ownerIdentifier: ownerIdentifier
        ),
        instanceFingerprint: namespace.fingerprint,
        ownerIdentifier: ownerIdentifier
      )
    } else {
      nil
    }
    return SharedSessionOwnerSlotClearRecovery.liveContext(
      ownerIdentifier: ownerIdentifier,
      currentIntent: intent,
      appLocalAccessGroup: appLocalAccessGroup
    )
  }
}
