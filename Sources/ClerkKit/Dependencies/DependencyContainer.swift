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
    let identity: any KeychainStorage
    let legacyAppLocal: (any KeychainStorage)?
    let localIdentityStore: (any SharedSessionLocalIdentityStoring)?
    let shouldHydrateProvisionalLegacyClient: Bool
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
    sharedSessionOwnerIdentifier = ownerIdentifierProvider()?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    persistentAdoptionEnabled = persistentAdoptionEnabledOverride
      ?? (!publishableKey.isEmpty && !EnvironmentDetection.isRunningInTests)
    sharedSessionOwnerSlotClearRecovery = if persistentAdoptionEnabled {
      Self.makeOwnerSlotClearRecovery(
        configuration: configurationManager,
        ownerIdentifier: sharedSessionOwnerIdentifier
      )
    } else {
      nil
    }
    if persistentAdoptionEnabled, !publishableKey.isEmpty {
      try SharedSessionOwnerSlotClearRecovery.recoverIfNeeded(
        in: sharedSessionOwnerSlotClearRecovery
      )
    }
    let keychainStorages = try Self.makeKeychainStorages(
      options: options,
      frontendApiUrl: configurationManager.frontendApiUrl,
      publishableKey: configurationManager.publishableKey,
      ownerIdentifier: sharedSessionOwnerIdentifier,
      usePersistentAdoptionState: persistentAdoptionEnabled,
      performPersistentAdoption: !deferSharedSessionAdoption
    )
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
        "x-mobile": "1",
      ]
    }

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

  private static func makeKeychainStorage(config: Clerk.Options.KeychainConfig) -> any KeychainStorage {
    makeKeychainStorage(service: config.service, accessGroup: config.normalizedAccessGroup)
  }

  private static func makeKeychainStorages(
    options: Clerk.Options,
    frontendApiUrl: String,
    publishableKey: String,
    ownerIdentifier: String?,
    usePersistentAdoptionState: Bool,
    performPersistentAdoption: Bool
  ) throws -> KeychainStorages {
    let config = options.keychainConfig
    let shared = makeKeychainStorage(config: config)
    let syncEnabled = options.sharedSessionSync != nil
    if syncEnabled, config.normalizedAccessGroup == nil {
      throw ClerkClientError(
        message: "Shared session sync requires a nonempty Keychain access group."
      )
    }
    if syncEnabled, ownerIdentifier?.isEmpty != false {
      throw ClerkClientError(
        message: "Shared session sync requires a nonempty application bundle identifier."
      )
    }

    let configuredAppLocal: any KeychainStorage = if config.normalizedAccessGroup != nil {
      makeKeychainStorage(service: config.service, accessGroup: nil)
    } else {
      shared
    }
    let previousAppLocal = makePreviousAppLocalKeychain(
      configuredService: config.service,
      bundleIdentifier: ownerIdentifier,
      configuredAppLocal: configuredAppLocal
    )
    let namespace = SharedSessionNamespace(
      frontendApiUrl: frontendApiUrl,
      publishableKey: publishableKey
    )
    let stableIdentity = makeKeychainStorage(
      service: stableIdentityService(
        configuredService: config.service,
        instanceFingerprint: namespace.fingerprint,
        ownerIdentifier: ownerIdentifier
      ),
      accessGroup: nil
    )

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
  func performDeferredSharedSessionAdoptionIfNeeded() throws {
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
    ).migrateIfNeeded()
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
    configuredAppLocal: any KeychainStorage
  ) -> (any KeychainStorage)? {
    guard let bundleIdentifier, !bundleIdentifier.isEmpty else {
      return nil
    }
    guard bundleIdentifier != configuredService else {
      return configuredAppLocal
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
    ownerIdentifier: String?
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
      currentIntent: intent
    )
  }
}
