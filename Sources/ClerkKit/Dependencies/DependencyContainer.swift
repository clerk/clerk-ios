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
    var layout: KeychainStorageLayout?
    var reconfigurationPreparation: ClerkIdentityStore.Preparation?
  }

  // MARK: - Core Dependencies

  let networkingPipeline: NetworkingPipeline
  let keychain: any KeychainStorage
  let appLocalKeychain: any KeychainStorage
  let identityStore: ClerkIdentityStore
  private let keychainStorages: KeychainStorages
  var identityIsInAccessGroup: Bool {
    keychainStorages.layout?.resolved?.identityIsInAccessGroup ?? keychainStorages.identityIsInAccessGroup
  }

  var sharesIdentity: Bool {
    if let layout = keychainStorages.layout {
      return layout.resolved?.identityIsInAccessGroup == true
    }
    return keychainStorages.identityIsInAccessGroup
  }

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
    isReconfiguration: Bool = false,
    migratesPersistentStateOverride: Bool? = nil,
    keychainStorageOverride: (any KeychainStorage)? = nil,
    keychainFactory: (@Sendable (String, String?) -> any KeychainStorage)? = nil,
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
      isReconfiguration: isReconfiguration,
      migratesPersistentState: migratesPersistentStateOverride
        ?? (!publishableKey.isEmpty && !EnvironmentDetection.isRunningInTests),
      keychainStorageOverride: keychainStorageOverride,
      makeKeychain: keychainFactory ?? Self.makeKeychainStorage
    )
    keychain = keychainStorages.shared
    appLocalKeychain = keychainStorages.appLocal
    identityStore = keychainStorages.identityStore
    self.keychainStorages = keychainStorages
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
}

extension DependencyContainer {
  private static func makeKeychainStorages(
    options: Clerk.Options,
    frontendApiUrl: String,
    publishableKey: String,
    ownerIdentifier: String?,
    isReconfiguration: Bool,
    migratesPersistentState: Bool,
    keychainStorageOverride: (any KeychainStorage)?,
    makeKeychain: @escaping @Sendable (String, String?) -> any KeychainStorage
  ) throws -> KeychainStorages {
    let namespace = SharedSessionNamespace(frontendApiUrl: frontendApiUrl, publishableKey: publishableKey)
    let syncEnabled = options.sharedSessionSync != nil

    if let keychainStorageOverride {
      guard !syncEnabled, !migratesPersistentState else {
        throw ClerkClientError(
          message: "Injected Keychain storage cannot be used with shared-session sync or storage migration.",
          localizationBundle: .module
        )
      }
      return KeychainStorages(
        shared: keychainStorageOverride,
        appLocal: keychainStorageOverride,
        identityStore: ClerkIdentityStore(keychain: keychainStorageOverride, instanceFingerprint: namespace.fingerprint),
        identityIsInAccessGroup: false
      )
    }

    let config = options.keychainConfig
    let shared = makeKeychain(config.service, config.normalizedAccessGroup)
    try validateSharedSessionConfiguration(enabled: syncEnabled, config: config, ownerIdentifier: ownerIdentifier)

    let configuredAppLocal = config.normalizedAccessGroup == nil ? shared : makeKeychain(config.service, nil)
    // Omitting an access group searches every accessible group. A different
    // service prevents local identity reads and clears from matching the shared record.
    let localIdentity = makeKeychain(
      localIdentityService(configuredService: config.service, ownerIdentifier: ownerIdentifier), nil
    )
    let adoptionMarkerKeychain = makeKeychain(
      stableIdentityService(configuredService: config.service, instanceFingerprint: namespace.fingerprint,
                            ownerIdentifier: ownerIdentifier), nil
    )

    guard migratesPersistentState else {
      return KeychainStorages(
        shared: shared, appLocal: syncEnabled ? configuredAppLocal : shared,
        identityStore: ClerkIdentityStore(keychain: shared, instanceFingerprint: namespace.fingerprint),
        identityIsInAccessGroup: config.normalizedAccessGroup != nil
      )
    }

    let handoff = ClerkIdentityStorageHandoff(
      config: config, instanceFingerprint: namespace.fingerprint,
      sharedKeychain: shared, localKeychain: localIdentity, markerKeychain: adoptionMarkerKeychain,
      makeKeychain: makeKeychain
    )
    let layout = makeKeychainLayout(
      syncEnabled: syncEnabled, config: config, shared: shared,
      configuredAppLocal: configuredAppLocal, localIdentity: localIdentity,
      localIdentityService: localIdentityService(configuredService: config.service, ownerIdentifier: ownerIdentifier),
      adoptionMarkerKeychain: adoptionMarkerKeychain,
      needsIsolatedLocalIdentity: {
        try handoff.hasSelection() || ClerkIdentityMigration.retiredSource(config.service, instanceFingerprint: namespace.fingerprint,
                                                                           journal: adoptionMarkerKeychain, makeKeychain: makeKeychain) != nil
      }
    )
    var identityStore = ClerkIdentityStore(
      keychain: DeferredKeychainStorage { try layout.get().identity },
      instanceFingerprint: namespace.fingerprint,
      clearIntentKeychain: adoptionMarkerKeychain,
      // A clear must be journaled before any storage read can fail. Include the
      // sharing mode so another configuration cannot consume the pending clear.
      clearIntentScope: ClerkIdentityStorageHandoff.clearIntentScope(config: config, syncEnabled: syncEnabled),
      watchSyncOwnerIdentifier: ownerIdentifier.nilIfEmpty ?? config.service
    )
    let migrationStore = identityStore
    let preparation = ClerkIdentityStore.Preparation {
      let selected = try layout.get()
      if syncEnabled, selected.sharedIsAccessible {
        try AppLocalStateAdoption(
          markerKeychain: adoptionMarkerKeychain, appLocal: configuredAppLocal, shared: shared,
          previousAppLocal: ownerIdentifier.flatMap { $0 == config.service ? nil : makeKeychain($0, nil) }
        ).adoptIfNeeded()
      }
      // Recheck on each preparation attempt, even if layout discovery succeeded earlier.
      // Only a missing entitlement permits intentionally incomplete local migration.
      if selected.sharedIsAccessible, config.normalizedAccessGroup != nil {
        _ = try shared.hasItem(forKey: ClerkKeychainKey.identity.rawValue)
      }
      if config.normalizedAccessGroup != nil || selected.identityService != config.service {
        // Honor an explicit clear before moving credentials to the selected backend.
        try migrationStore.recoverPendingClear()
        try handoff.prepare(isShared: selected.identityIsInAccessGroup, clearIntentScope: migrationStore.clearIntentScope)
      }
      let migration = try ClerkIdentityMigration(
        store: migrationStore, legacyKeychain: shared, markerKeychain: configuredAppLocal,
        configuredService: config.service, accessGroup: config.normalizedAccessGroup,
        ownerIdentifier: ownerIdentifier, instanceFingerprint: namespace.fingerprint,
        destination: .init(service: selected.identityService, accessGroup: selected.identityIsInAccessGroup ? config.normalizedAccessGroup : nil),
        previousAppLocalService: syncEnabled ? ownerIdentifier : nil,
        readsLegacyItems: !AppLocalStateAdoption.hasLegacyIdentityAdoption(in: adoptionMarkerKeychain),
        readsSharedLegacyItems: selected.sharedIsAccessible,
        readsSharedSlots: selected.identityIsInAccessGroup, finalizes: selected.sharedIsAccessible,
        makeKeychain: makeKeychain
      )
      try migration.migrateIfNeeded()
    }
    // Validation and clearing need the correct routing, but must not copy credentials.
    identityStore.preparation = isReconfiguration ? .init { _ = try layout.get() } : preparation
    do {
      try identityStore.prepareForUse()
    } catch let error as KeychainError {
      ClerkLogger.logError(error, message: "Clerk storage is unavailable; preparation will retry before identity access")
    }
    return KeychainStorages(
      shared: shared, appLocal: DeferredKeychainStorage { try layout.get().appLocal },
      identityStore: identityStore, identityIsInAccessGroup: config.normalizedAccessGroup != nil,
      layout: layout,
      reconfigurationPreparation: isReconfiguration ? preparation : nil
    )
  }

  private static func makeKeychainLayout(
    syncEnabled: Bool,
    config: Clerk.Options.KeychainConfig,
    shared: any KeychainStorage,
    configuredAppLocal: any KeychainStorage,
    localIdentity: any KeychainStorage,
    localIdentityService: String,
    adoptionMarkerKeychain: any KeychainStorage,
    needsIsolatedLocalIdentity: @escaping @Sendable () throws -> Bool
  ) -> KeychainStorageLayout {
    KeychainStorageLayout {
      // A failed marker read is unknown, never evidence that adoption did not happen.
      let wasAdopted = try AppLocalStateAdoption.usesAppLocalStorage(in: adoptionMarkerKeychain)
      // Keep the selected identity when removing an access group, including a
      // fallback login. A retained unscoped V4 source must not become authoritative again.
      let needsLocalIdentity = try wasAdopted || (config.normalizedAccessGroup == nil && needsIsolatedLocalIdentity())
      var identity: any KeychainStorage = syncEnabled || !needsLocalIdentity ? shared : localIdentity
      var identityService = syncEnabled || !needsLocalIdentity ? config.service : localIdentityService
      var isShared = config.normalizedAccessGroup != nil && (syncEnabled || !needsLocalIdentity)
      var sharedIsAccessible = true
      if config.normalizedAccessGroup != nil {
        do {
          _ = try shared.hasItem(forKey: ClerkKeychainKey.identity.rawValue)
        } catch let error as KeychainError where error.isMissingEntitlement {
          ClerkLogger.error(
            "Clerk cannot access the configured Keychain access group, so authentication stays local to this app and shared-session sync is off. Add the access group to this app's Keychain Sharing entitlement, then relaunch."
          )
          identity = localIdentity
          identityService = localIdentityService
          isShared = false
          sharedIsAccessible = false
        }
        // Other errors leave resolution unfinished. The next access probes again,
        // so temporary unavailability cannot permanently exclude legacy credentials.
      }
      return KeychainStorageLayout.Selection(
        identity: identity, identityService: identityService,
        appLocal: syncEnabled || wasAdopted || !sharedIsAccessible ? configuredAppLocal : shared,
        identityIsInAccessGroup: isShared, sharedIsAccessible: sharedIsAccessible
      )
    }
  }

  private static func validateSharedSessionConfiguration(
    enabled: Bool, config: Clerk.Options.KeychainConfig, ownerIdentifier: String?
  ) throws {
    guard enabled else { return }
    guard config.normalizedAccessGroup != nil else {
      throw ClerkClientError(
        message: "Shared session sync requires a nonempty Keychain access group.", localizationBundle: .module
      )
    }
    guard ownerIdentifier?.isEmpty == false else {
      throw ClerkClientError(
        message: "Shared session sync requires a nonempty application bundle identifier.", localizationBundle: .module
      )
    }
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

  static func localIdentityService(configuredService: String, ownerIdentifier: String?) -> String {
    let owner = ownerIdentifier.nilIfEmpty ?? configuredService
    return "\(owner).clerk.local-identity.\(SharedSessionNamespace.sha256(configuredService))"
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

extension DependencyContainer {
  var watchSyncKeychain: any KeychainStorage {
    let shared = keychain
    guard let layout = keychainStorages.layout else {
      return MigratingKeychainStorage(primary: appLocalKeychain, fallback: shared)
    }
    return DeferredKeychainStorage {
      let selected = try layout.get()
      guard selected.sharedIsAccessible else { return selected.appLocal }
      return MigratingKeychainStorage(primary: selected.appLocal, fallback: shared)
    }
  }

  /// Run only after both configurations' local credentials have been cleared.
  /// An empty destination becomes authoritative before normal migration or handoff
  /// can import a login. A destination identity already shared by peers is preserved.
  func finishReconfiguration() throws {
    guard let preparation = keychainStorages.reconfigurationPreparation else { return }
    if try identityStore.load() == nil {
      do {
        try identityStore.save(.signedOut, replacing: nil)
      } catch ClerkIdentityStoreError.writeConflict {
        _ = try identityStore.load()
      }
    }
    try preparation.run()
  }
}
