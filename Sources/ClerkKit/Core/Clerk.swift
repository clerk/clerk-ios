//
//  Clerk.swift
//

// swiftlint:disable file_length

import Foundation

/**
 This is the main entrypoint class for the clerk package. It contains a number of methods and properties for interacting with the Clerk API.
 */
@MainActor
@Observable
public final class Clerk {
  /// The shared Clerk instance.
  ///
  /// Accessing this property before calling `Clerk.configure(publishableKey:options:)` will trigger an assertion failure in debug builds.
  /// In release builds, a new unconfigured `Clerk` instance is returned.
  public static var shared: Clerk {
    guard let instance = _shared else {
      assertionFailure("Clerk has not been configured. Call Clerk.configure(publishableKey:options:) before accessing Clerk.shared")
      return Clerk()
    }
    return instance
  }

  /// Private shared instance that is set during configuration.
  private static var _shared: Clerk?

  /// The installed logging configuration, when Clerk has completed configuration.
  static var installedLoggingConfiguration: ClerkLogger.Configuration? {
    _shared.map { ClerkLogger.Configuration(options: $0.options) }
  }

  private static var isRuntimeReconfigurationInProgress = false

  private struct ReconfigurationRollbackState {
    let configurationEpoch: ClerkConfigurationEpoch
    let dependencies: any Dependencies
    let identity: ClerkIdentityController.RollbackState
  }

  private enum ReconfigurationPlan: Equatable {
    case preserveIdentityAndSlot
    case preserveIdentityAndMigrateSlot
    case replaceIdentity

    var reusesOwnerSlot: Bool {
      self == .preserveIdentityAndSlot
    }
  }

  /// A getter to see if the Clerk object is ready for use or not.
  /// Returns true when both environment and client are loaded.
  public var isLoaded: Bool {
    environment != nil && client != nil
  }

  /// A getter to see if a Clerk instance is running in production or development mode.
  public var instanceType: InstanceEnvironmentType {
    dependencies.configurationManager.instanceType
  }

  /// Whether ClerkKitUI should show the development mode warning.
  public var shouldShowDevelopmentModeWarning: Bool {
    guard let displayConfig = environment?.displayConfig else { return false }
    return displayConfig.showDevmodeWarning && displayConfig.instanceEnvironmentType != .production
  }

  /// The Client object for the current device.
  public internal(set) var client: Client? {
    didSet {
      identityController.validateClientMutation()
      // Emit session change event if the session changed
      if SessionUtils.sessionChanged(previousClient: oldValue, currentClient: client) {
        auth.send(.sessionChanged(oldValue: oldValue?.currentSession, newValue: client?.currentSession))
      }

      if let client {
        cacheManager?.saveClient(client, serverFetchDate: lastClientServerFetchDate)
        dependencies.sessionStatusLogger.logPendingSessionStatusIfNeeded(previousClient: oldValue, currentClient: client)
      } else {
        cacheManager?.deleteClient(serverFetchDate: lastClientServerFetchDate)
      }

      emitInternalStateChange(.clientDidChange(previous: oldValue, current: client))
    }
  }

  /// The telemetry collector for development diagnostics.
  ///
  /// Uses dependency injection with a no-op default that is replaced with a real collector
  /// during configuration if telemetry is enabled.
  /// Used to record non-blocking telemetry events when running in development
  package var telemetry: any TelemetryCollectorProtocol {
    dependencies.telemetryCollector
  }

  /// Your Clerk app's proxy URL. Required for applications that run behind a reverse proxy. Must be a full URL (for example, https://proxy.example.com/__clerk).
  public private(set) var proxyUrl: URL? {
    get {
      dependencies.configurationManager.proxyUrl
    }
    set {
      dependencies.configurationManager.updateProxyUrl(newValue)
    }
  }

  /// The current session for the device.
  public var session: Session? {
    client?.currentSession
  }

  /// The current user for the device.
  public var user: User? {
    session?.user
  }

  /// The current user's membership in the active organization.
  public var organizationMembership: OrganizationMembership? {
    guard let activeOrganizationId = session?.lastActiveOrganizationId else {
      return nil
    }

    return user?.organizationMemberships?.first { $0.organization.id == activeOrganizationId }
  }

  /// The active organization for the current session.
  public var organization: Organization? {
    organizationMembership?.organization
  }

  /// A dictionary of a user's active sessions on all devices.
  public internal(set) var sessionsByUserId: [String: [Session]] = [:]

  /// Server timestamp from the response that last updated the local client.
  /// Used as a cross-device ordering key, since it comes from a
  /// single clock (the server) and advances on every API response.
  var lastClientServerFetchDate: Date? {
    identityController.lastServerDate
  }

  /// Changes when local device-token ownership changes.
  /// Client responses prepared before this value changes must not update state.
  var clientResponseGeneration: ClientResponseGeneration {
    identityController.clientResponseGeneration
  }

  /// Shared refresh task used to coalesce invalid-auth recovery refreshes.
  private var invalidAuthRefreshTask: Task<Void, Never>?

  /// Configure-time client refresh, canceled when tokenless client creation starts.
  private var startupClientRefreshTask: Task<Void, Never>?
  private var startupClientRefreshID: UUID?

  @ObservationIgnored
  lazy var startupClientRefreshTakeover = StartupClientRefreshTakeover(clerk: self)

  /// Changes every time this instance is reconfigured.
  /// SDK-owned requests capture this value so stale responses cannot mutate new state.
  private(set) var configurationEpoch: ClerkConfigurationEpoch = .initial

  /// Thread-safe runtime state used by SDK-owned dependencies to detect stale work.
  let runtimeState = ClerkRuntimeState()

  /// The publishable key from your Clerk Dashboard, used to connect to Clerk.
  public var publishableKey: String {
    dependencies.configurationManager.publishableKey
  }

  /// The Clerk environment for the instance.
  public internal(set) var environment: Environment? {
    didSet {
      if let environment {
        cacheManager?.saveEnvironment(environment)
        emitInternalStateChange(.environmentDidChange)
      }
    }
  }

  package struct EnvironmentRefreshCheckpoint: Equatable {
    fileprivate let revision: Int
  }

  private var environmentRefreshRevision = 0
  private var environmentRefreshTask: Task<Environment, Error>?
  private var environmentRefreshTaskID: UUID?

  package var environmentRefreshCheckpoint: EnvironmentRefreshCheckpoint {
    .init(revision: environmentRefreshRevision)
  }

  /// The configuration options for this Clerk instance.
  public var options: Clerk.Options {
    dependencies.configurationManager.options
  }

  /// Coordinates task lifecycle and cleanup.
  private var taskCoordinator: TaskCoordinator? = TaskCoordinator()

  /// Frontend API URL.
  var frontendApiUrl: String {
    dependencies.configurationManager.frontendApiUrl
  }

  // MARK: - Lifecycle Managers

  // These managers coordinate Clerk-specific lifecycle concerns and require Clerk as a dependency.

  /// Manages caching of client and environment data.
  var cacheManager: CacheManager?

  /// Manages periodic polling of session tokens to keep them refreshed.
  private var sessionPollingManager: SessionPollingManager?

  /// Manages app lifecycle notifications and coordinates foreground/background transitions.
  private var lifecycleManager: LifecycleManager?

  /// Coordinates shared persisted auth state between sibling apps.
  var sharedSessionSyncCoordinator: SharedSessionSyncCoordinator?

  /// Owns complete authentication identity transitions and persistence routing.
  @ObservationIgnored
  lazy var identityController = ClerkIdentityController(clerk: self)

  /// Coordinates authentication state exchanged with a paired Apple Watch.
  private var watchConnectivityCoordinator: WatchConnectivityCoordinator?

  /// Coalesces overlapping public Keychain clears so persistence remains frozen
  /// until the single clear transaction has completed.
  var keychainClearTask: Task<Void, Error>?

  /// Dispatches Clerk state changes to optional internal observers.
  var internalStateChanges = ClerkInternalStateChangeEmitter()

  /// Dependency container holding all SDK dependencies.
  var dependencies: any Dependencies

  /// The event emitter for auth events.
  /// Owned by Clerk to ensure stable identity across accesses to `auth`.
  private let authEventEmitter = EventEmitter<AuthEvent>()
  /// Coalesces duplicate URL handling tasks triggered by multiple UI surfaces.
  private let urlHandlingCoordinator = URLHandlingCoordinator()
  /// Callback-scoped auth continuation used internally by `AuthView` to resume recovered flows.
  package private(set) var callbackContinuation: TransferFlowResult?

  /// The main entry point for all authentication operations.
  ///
  /// Use this property to perform sign in, sign up, and session management operations.
  /// This is a lightweight facade - Clerk owns the underlying EventEmitter.
  public var auth: Auth {
    Auth(
      magicLinkStore: dependencies.magicLinkStore,
      magicLinkService: dependencies.magicLinkService,
      signInService: dependencies.signInService,
      signUpService: dependencies.signUpService,
      sessionService: dependencies.sessionService,
      eventEmitter: authEventEmitter,
      urlHandlingCoordinator: urlHandlingCoordinator
    )
  }

  package func setCallbackContinuation(_ result: TransferFlowResult?) {
    callbackContinuation = result
  }

  /// The main entry point for organization operations.
  ///
  /// Use this property to create organizations.
  public var organizations: Organizations {
    Organizations(organizationService: dependencies.organizationService)
  }

  /// Proxy configuration derived from `proxyUrl`, if present.
  var proxyConfiguration: ProxyConfiguration? {
    dependencies.configurationManager.proxyConfiguration
  }

  package init() {
    // Create temporary container - will be replaced during configure with proper values
    do {
      dependencies = try DependencyContainer(
        publishableKey: "",
        options: .init(),
        runtimeScope: .init(epoch: .initial)
      )
    } catch {
      // This should never happen, but handle it just in case
      assertionFailure("Failed to create temporary dependency container: \(error.localizedDescription)")
      if let fallbackDependencies = try? DependencyContainer(
        publishableKey: "",
        options: .init(),
        runtimeScope: .init(epoch: .initial)
      ) {
        dependencies = fallbackDependencies
      } else {
        fatalError("Failed to create temporary dependency container")
      }
    }
  }
}

extension Clerk {
  /// Internal helper method that performs the actual configuration work.
  @MainActor
  func performConfiguration(publishableKey: String, options: Clerk.Options) throws {
    let dependencies = try DependencyContainer(
      publishableKey: publishableKey,
      options: options,
      runtimeScope: runtimeScope
    )
    try dependencies.discardPendingPublicationWhenSharedSyncDisabled()

    performConfiguration(dependencies: dependencies)
  }

  /// Internal helper method that installs a prebuilt dependency container and starts managers.
  @MainActor
  func performConfiguration(dependencies: any Dependencies) {
    cancelStartupClientRefresh()
    identityController.prepareForConfiguration()
    taskCoordinator?.cancelAll()
    watchConnectivityCoordinator?.stopAcceptingIdentityUpdates()
    watchConnectivityCoordinator = nil
    internalStateChanges.removeAllObservers()
    sharedSessionSyncCoordinator = nil

    // Initialize task coordinator
    taskCoordinator = TaskCoordinator()

    self.dependencies = dependencies
    let usesSharedSessionSync = options.sharedSessionSync != nil

    // Set up session polling and lifecycle management
    sessionPollingManager = SessionPollingManager(
      sessionProvider: self,
      authEventsProvider: { [weak self] in
        self?.auth.events ?? AsyncStream { $0.finish() }
      }
    )
    lifecycleManager = LifecycleManager(handler: self)
    sessionPollingManager?.startPolling()
    lifecycleManager?.startObserving()

    // Set up cache manager and load cached data synchronously
    let cacheManager = CacheManager(
      coordinator: self,
      identityKeychain: dependencies.identityKeychain,
      environmentKeychain: dependencies.appLocalKeychain,
      provisionalClientKeychains: [
        dependencies.appLocalKeychain,
        dependencies.legacyAppLocalKeychain,
        dependencies.keychain,
      ].compactMap { $0 },
      atomicIdentityStore: dependencies.atomicIdentityStore
    )
    self.cacheManager = cacheManager
    cacheManager.loadCachedData(hydrateIdentity: !usesSharedSessionSync)
    if usesSharedSessionSync, dependencies.shouldHydrateProvisionalLegacyClient {
      cacheManager.loadProvisionalLegacyClientForPresentation()
    }

    let initialSharedSessionReconciliation = startSharedSessionSyncIfNeeded(
      dependencies: dependencies
    )

    // Set up watch connectivity coordinator only after cache hydration.
    // Restored cached state should not be versioned as a new local auth change.
    if options.watchConnectivityEnabled {
      let coordinator = WatchConnectivityCoordinator()
      watchConnectivityCoordinator = coordinator
      internalStateChanges.addObserver(coordinator)
    }

    // Fire and forget: fetch fresh client and environment from API
    let retryPolicy = Self.startupRefreshRetryPolicy
    taskCoordinator?.task { @MainActor [weak self] in
      do {
        guard let self else { return }
        _ = try await retryingOperation(
          policy: retryPolicy,
          operationName: "environment refresh"
        ) {
          try await self.refreshEnvironment()
        }
      } catch is CancellationError {
        return
      } catch {
        ClerkLogger.logError(error, message: "Failed to load environment")
      }
    }

    startStartupClientRefreshIfNeeded(after: initialSharedSessionReconciliation)
  }

  func startStartupClientRefreshIfNeeded(
    after initialSharedSessionReconciliation: Task<Bool, Never>? = nil
  ) {
    guard startupClientRefreshTask == nil,
          let taskCoordinator
    else {
      return
    }

    let retryPolicy = Self.startupRefreshRetryPolicy
    let startupClientRefreshID = UUID()
    self.startupClientRefreshID = startupClientRefreshID
    startupClientRefreshTask = taskCoordinator.task { @MainActor [weak self] in
      guard let self else { return }
      defer {
        if self.startupClientRefreshID == startupClientRefreshID {
          self.startupClientRefreshTask = nil
          self.startupClientRefreshID = nil
        }
      }
      do {
        _ = await initialSharedSessionReconciliation?.value
        try Task.checkCancellation()
        _ = try await retryingOperation(
          policy: retryPolicy,
          operationName: "client refresh"
        ) {
          try Task.checkCancellation()
          try await self.refreshClient(skipClientId: false)
        }
      } catch is CancellationError {
        return
      } catch {
        ClerkLogger.logError(error, message: "Failed to load client")
      }
    }
  }

  @MainActor
  private func startSharedSessionSyncIfNeeded(
    dependencies: any Dependencies
  ) -> Task<Bool, Never>? {
    guard options.sharedSessionSync != nil else { return nil }
    guard options.keychainConfig.normalizedAccessGroup != nil,
          let ownerIdentifier = dependencies.sharedSessionOwnerIdentifier,
          !ownerIdentifier.isEmpty,
          let localIdentityStore = dependencies.atomicIdentityStore
    else {
      ClerkLogger.error(
        "Shared session sync requires a Keychain access group, bundle identifier, and app-local identity store."
      )
      return nil
    }

    do {
      let namespace = SharedSessionNamespace(
        frontendApiUrl: frontendApiUrl,
        publishableKey: publishableKey
      )
      let slotStore = try SharedSessionOwnerSlotStore(
        keychainConfig: options.keychainConfig,
        namespace: namespace,
        ownerIdentifier: ownerIdentifier
      )
      let coordinator = SharedSessionSyncCoordinator(
        ownerIdentifier: ownerIdentifier,
        instanceFingerprint: namespace.fingerprint,
        slotStore: slotStore,
        localIdentityStore: localIdentityStore,
        localIdentityIO: dependencies.atomicIdentityIO,
        notifier: SharedSessionSyncDarwinNotifier(
          keychainConfig: options.keychainConfig,
          instanceFingerprint: namespace.fingerprint
        ),
        configurationEpoch: configurationEpoch,
        clerk: self
      )
      sharedSessionSyncCoordinator = coordinator
      internalStateChanges.addObserver(coordinator)
      coordinator.hydrateInitialSharedState()
      return coordinator.start()
    } catch {
      ClerkLogger.logError(error, message: "Failed to install shared session sync")
      return nil
    }
  }

  /// Configures the shared Clerk instance.
  ///
  /// Call this method once at app launch before accessing `Clerk.shared`.
  ///
  /// - Parameters:
  ///     - publishableKey: The publishable key from your Clerk Dashboard.
  ///     - options: Configuration options for the Clerk instance.
  /// - Returns: The configured Clerk instance.
  @MainActor
  @discardableResult
  public static func configure(
    publishableKey: String,
    options: Clerk.Options = .init()
  ) -> Clerk {
    // Allow reconfiguration in test environments for test isolation
    if let existing = _shared {
      if EnvironmentDetection.isRunningInTests {
        // Clean up old managers before resetting to prevent background tasks from interfering
        existing.cleanupManagers()
        _shared = nil
      } else {
        ClerkLogger.warning("Clerk has already been configured. Configure can only be called once.")
        return existing
      }
    }

    let clerk = Clerk()

    do {
      try clerk.performConfiguration(publishableKey: publishableKey, options: options)
    } catch {
      assertionFailure("Failed to configure Clerk: \(error.localizedDescription)")
      return Clerk()
    }

    _shared = clerk
    return clerk
  }

  /// Reconfigures the shared Clerk instance with a new publishable key and options.
  ///
  /// This method validates and installs the new configuration. Changing the publishable
  /// key clears local Clerk state. Reconfiguring shared-session transport for the same
  /// publishable key preserves the adopted app-local identity while updating this app's
  /// shared owner slot as needed.
  ///
  /// If Clerk has not been configured yet, this method creates and installs the shared
  /// instance without going through the fallback ``Clerk/shared`` getter.
  ///
  /// - Parameters:
  ///   - publishableKey: The new publishable key from your Clerk Dashboard.
  ///   - options: Configuration options for the Clerk instance.
  /// - Returns: The configured shared Clerk instance.
  /// - Throws: An error if the new configuration is invalid.
  ///
  /// Example:
  /// ```swift
  /// try await Clerk.reconfigure(
  ///   publishableKey: selectedRegion.publishableKey,
  ///   options: .init(proxyUrl: selectedRegion.proxyUrl)
  /// )
  /// ```
  @MainActor
  @discardableResult
  public static func reconfigure(
    publishableKey: String,
    options: Clerk.Options = .init()
  ) async throws -> Clerk {
    try beginRuntimeReconfiguration()
    defer { endRuntimeReconfiguration() }

    if let existing = _shared {
      // A public Keychain clear owns deletion of the current atomic identity.
      // Let that transaction commit before reconfiguration invalidates the old
      // runtime's identity queue or decides whether local state can be reused.
      try await existing.keychainClearTask?.value

      let nextEpoch = existing.nextConfigurationEpoch
      let newDependencies = try DependencyContainer(
        publishableKey: publishableKey,
        options: options,
        runtimeScope: .init(epoch: nextEpoch, runtimeState: existing.runtimeState),
        deferSharedSessionAdoption: true
      )
      let plan = existing.reconfigurationPlan(with: newDependencies)
      let rollbackState = existing.captureReconfigurationRollbackState()

      existing.setConfigurationEpoch(to: nextEpoch)
      await existing.cleanupManagersAndDrainCache(
        deleteSharedSessionOwnerSlot: false
      )

      do {
        switch plan {
        case .preserveIdentityAndSlot:
          try newDependencies.performDeferredSharedSessionAdoptionIfNeeded()
        case .preserveIdentityAndMigrateSlot:
          try preserveAcceptedIdentityAcrossTopologyChange(
            from: rollbackState.dependencies.atomicIdentityStore,
            to: newDependencies.atomicIdentityStore
          )
          try rollbackState.dependencies.atomicIdentityStore?
            .clearPendingPublication()
          try newDependencies.performDeferredSharedSessionAdoptionIfNeeded()
        case .replaceIdentity:
          try await clearLocalClerkStorageStrictly(in: newDependencies)
          try await clearLocalClerkStorageStrictly(
            in: rollbackState.dependencies,
            deleteSharedSessionOwnerSlot: false
          )
          try newDependencies.markSharedSessionAdoptedWithoutMigratingCredentialsIfNeeded()
        }
        try newDependencies.discardPendingPublicationWhenSharedSyncDisabled()
        if !plan.reusesOwnerSlot {
          try await SharedSessionOwnerSlotCleanup.deleteIfConfigured(
            in: rollbackState.dependencies
          )
        }
      } catch {
        existing.restoreAfterFailedReconfiguration(rollbackState)
        throw error
      }

      await existing.resetRuntimeStateForReconfiguration()
      existing.performConfiguration(dependencies: newDependencies)
      return existing
    }

    let clerk = Clerk()
    let newDependencies = try DependencyContainer(
      publishableKey: publishableKey,
      options: options,
      runtimeScope: clerk.runtimeScope,
      deferSharedSessionAdoption: true
    )

    try await clearLocalClerkStorageStrictly(in: newDependencies)
    try newDependencies.markSharedSessionAdoptedWithoutMigratingCredentialsIfNeeded()
    try newDependencies.discardPendingPublicationWhenSharedSyncDisabled()
    clerk.performConfiguration(dependencies: newDependencies)
    _shared = clerk
    return clerk
  }

  @MainActor
  package static func resetSharedInstanceForTesting() async {
    guard EnvironmentDetection.isRunningInTests else {
      return
    }

    guard let shared = _shared else { return }

    await shared.cleanupManagersAndDrainCache()
    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()
    _shared = nil
  }

  /// Refreshes the current client from the API.
  @discardableResult
  public func refreshClient() async throws -> Client? {
    try await refreshClient(skipClientId: false)
  }

  /// Refreshes the current client from the API.
  ///
  /// - Parameter skipClientId: When `true`, omits the currently cached client id
  ///   from the request while still sending the stored device token. This is used
  ///   after replacing the device token so a stale client id from the previous
  ///   native client cannot conflict with the newly stored token.
  @discardableResult
  func refreshClient(skipClientId: Bool) async throws -> Client? {
    try Task.checkCancellation()
    let runtime = runtimeScope
    let clientResponseGeneration = clientResponseGeneration
    let response = try await dependencies.clientService.getResponse(skipClientId: skipClientId)
    try Task.checkCancellation()
    try runtime.validateStableRuntime()
    switch response.update {
    case .client(let responseClient):
      identityController.applyDecodedClientFallback(
        responseClient,
        responseSequence: response.requestSequence,
        serverDate: response.serverDate,
        clientResponseGeneration: clientResponseGeneration
      )
    case .preserve:
      break
    }
    return client
  }

  /// Refreshes the current environment from the API.
  @discardableResult
  public func refreshEnvironment() async throws -> Environment {
    if let environmentRefreshTask {
      return try await environmentRefreshTask.value
    }

    let runtime = runtimeScope
    let taskID = UUID()
    let task = Task { @MainActor in
      defer {
        if self.environmentRefreshTaskID == taskID {
          self.environmentRefreshTask = nil
          self.environmentRefreshTaskID = nil
        }
      }

      let environment = try await self.dependencies.environmentService.get()
      try Task.checkCancellation()
      try runtime.validateStableRuntime()
      self.environment = environment
      self.environmentRefreshRevision += 1
      return environment
    }

    environmentRefreshTask = task
    environmentRefreshTaskID = taskID
    return try await task.value
  }

  @discardableResult
  package func ensureEnvironmentRefreshed(after checkpoint: EnvironmentRefreshCheckpoint) async throws -> Environment {
    if environmentRefreshRevision > checkpoint.revision, let environment {
      return environment
    }

    return try await refreshEnvironment()
  }

  private static let startupRefreshRetryPolicy = RetryPolicy(
    maxAttempts: 3,
    initialDelay: .milliseconds(500),
    maximumDelay: .seconds(5)
  )

  /// Handles an incoming URL, routing it to the appropriate handler.
  ///
  /// If the URL matches a known Clerk callback (e.g. a magic link), it will
  /// be processed automatically and this method returns `true`. Unrecognized
  /// URLs are ignored and this method returns `false`.
  ///
  /// ```swift
  /// .onOpenURL { url in
  ///   Task { try? await clerk.handle(url) }
  /// }
  /// ```
  @discardableResult
  public func handle(_ url: URL) async throws -> Bool {
    guard let route = try ClerkURLRoute(url: url, redirectUrl: options.redirectConfig.redirectUrl) else {
      return false
    }

    try await auth.handle(route)
    return true
  }

  @MainActor
  private func resetRuntimeStateForReconfiguration() async {
    await SessionTokenFetcher.shared.reset()
    await SessionTokensCache.shared.clear()

    identityController.resetRuntimeIdentity()
    environment = nil
    sessionsByUserId = [:]
    WebAuthentication.cancelCurrentSession()

    #if canImport(AuthenticationServices) && !os(watchOS)
    PasskeyHelper.cancelCurrentAuthorization()
    #endif
  }
}

extension Clerk: CacheCoordinator {
  func hydrateIdentityIfNeeded(_ identity: ClerkIdentitySnapshot) {
    identityController.hydrateAtomicIdentityIfNeeded(identity)
  }

  func setClientIfNeeded(_ client: Client?, serverFetchDate: Date?) {
    identityController.hydrateLegacyClientIfNeeded(client, serverDate: serverFetchDate)
  }

  func setServerFetchDateIfNeeded(_ date: Date) {
    identityController.hydrateLegacyServerDateIfNeeded(date)
  }

  func setEnvironmentIfNeeded(_ environment: Clerk.Environment) {
    // Only set if environment hasn't been loaded yet
    // This prevents cached data from overwriting fresh data loaded from the API
    guard self.environment == nil else { return }
    self.environment = environment
  }
}

extension Clerk: SessionProviding {}

extension Clerk: LifecycleEventHandling {
  /// Handles the app entering the foreground by resuming session polling and refreshing data.
  func onWillEnterForeground() async {
    sessionPollingManager?.startPolling()

    emitInternalStateChange(.applicationDidEnterForeground)

    #if os(macOS)
    if WebAuthentication.consumePendingForegroundRefreshSuppression() {
      return
    }
    #endif

    // Refresh client and environment concurrently
    taskCoordinator?.task { [weak self] in
      guard let self else { return }
      do {
        try await refreshClient()
      } catch {
        ClerkLogger.logError(error, message: "Failed to refresh client on foreground")
      }

      // Force an immediate token evaluation after foreground client refresh
      // rather than waiting for the next polling interval.
      await sessionPollingManager?.refreshNowIfNeeded()
    }

    taskCoordinator?.task { [weak self] in
      guard let self else { return }
      do {
        _ = try await refreshEnvironment()
      } catch {
        ClerkLogger.logError(error, message: "Failed to refresh environment on foreground")
      }
    }
  }

  /// Handles the app entering the background by stopping session polling and flushing telemetry.
  func onDidEnterBackground() async {
    sessionPollingManager?.stopPolling()

    taskCoordinator?.task(priority: .utility) { [weak self] in
      await self?.telemetry.flush()
    }
  }
}

extension Clerk {
  /// Applies a client value after the identity controller has established its mutation boundary.
  func setClientFromIdentityController(_ client: Client?) {
    self.client = client
  }

  func emitInternalStateChange(_ change: ClerkInternalStateChange) {
    do {
      try internalStateChanges.emit(change, from: self)
    } catch {
      ClerkLogger.logError(error, message: "Failed to notify Clerk state observer")
    }
  }

  @discardableResult
  func scheduleManagedTask(
    priority: TaskPriority = .userInitiated,
    operation: @escaping @Sendable () async -> Void
  ) -> Task<Void, Never>? {
    taskCoordinator?.task(priority: priority, operation: operation)
  }

  @discardableResult
  func cancelStartupClientRefreshTask() -> Bool {
    guard let startupClientRefreshTask else { return false }
    self.startupClientRefreshTask = nil
    startupClientRefreshID = nil
    startupClientRefreshTask.cancel()
    return true
  }

  var isStartupClientRefreshInProgress: Bool {
    startupClientRefreshTask != nil
  }

  @discardableResult
  func cancelStartupClientRefresh() -> Bool {
    startupClientRefreshTakeover.cancel()
    return cancelStartupClientRefreshTask()
  }

  @MainActor
  static func beginRuntimeReconfiguration() throws {
    guard !isRuntimeReconfigurationInProgress else {
      throw ClerkClientError(message: "Clerk is already reconfiguring. Wait for the current reconfiguration to finish before starting another one.")
    }
    isRuntimeReconfigurationInProgress = true
    _shared?.runtimeState.beginReconfiguration()
  }

  @MainActor
  static func endRuntimeReconfiguration() {
    isRuntimeReconfigurationInProgress = false
    _shared?.runtimeState.endReconfiguration()
  }

  @MainActor
  static func requireStableRuntime() throws -> ClerkRuntimeScope {
    guard !isRuntimeReconfigurationInProgress else {
      throw CancellationError()
    }

    guard let shared = _shared else {
      throw ClerkClientError(message: "Clerk must be configured before getting a session token.")
    }

    return shared.runtimeScope
  }

  var runtimeScope: ClerkRuntimeScope {
    ClerkRuntimeScope.current(clerkProvider: { self })
  }

  var nextConfigurationEpoch: ClerkConfigurationEpoch {
    configurationEpoch.next()
  }

  func setConfigurationEpoch(to epoch: ClerkConfigurationEpoch) {
    configurationEpoch = epoch
    runtimeState.advance(to: epoch)
  }

  private func captureReconfigurationRollbackState() -> ReconfigurationRollbackState {
    ReconfigurationRollbackState(
      configurationEpoch: configurationEpoch,
      dependencies: dependencies,
      identity: identityController.captureRollbackState()
    )
  }

  private func restoreAfterFailedReconfiguration(_ state: ReconfigurationRollbackState) {
    setConfigurationEpoch(to: state.configurationEpoch)
    identityController.restoreRollbackState(state.identity)
    performConfiguration(dependencies: state.dependencies)
  }

  private static func preserveAcceptedIdentityAcrossTopologyChange(
    from source: (any SharedSessionLocalIdentityStoring)?,
    to destination: (any SharedSessionLocalIdentityStoring)?
  ) throws {
    guard let identity = try source?.load(), let destination else { return }
    try destination.updateRecord { _ in
      SharedSessionLocalIdentityRecord(
        acceptedIdentity: identity,
        pendingPublication: nil
      )
    }
  }

  private func reconfigurationPlan(
    with newDependencies: any Dependencies
  ) -> ReconfigurationPlan {
    let preservesIdentity = publishableKey
      == newDependencies.configurationManager.publishableKey
      && (options.sharedSessionSync != nil
        || newDependencies.configurationManager.options.sharedSessionSync != nil)
    guard preservesIdentity else {
      return .replaceIdentity
    }
    return canReuseSharedSessionOwnerSlot(with: newDependencies)
      ? .preserveIdentityAndSlot
      : .preserveIdentityAndMigrateSlot
  }

  func isCurrentConfigurationEpoch(_ epoch: ClerkConfigurationEpoch) -> Bool {
    configurationEpoch == epoch
  }

  func refreshClientAfterInvalidAuth() async {
    let task = startRefreshClientAfterInvalidAuth()
    await task.value
  }

  func startRefreshClientAfterInvalidAuth() -> Task<Void, Never> {
    if let invalidAuthRefreshTask {
      return invalidAuthRefreshTask
    }

    let task = Task { [self] in
      defer { invalidAuthRefreshTask = nil }

      do {
        try await refreshClient()
      } catch {
        ClerkLogger.logError(error, message: "Failed to refresh client after invalid authentication response")
      }
    }

    invalidAuthRefreshTask = task
    return task
  }

  /// Cleans up managers that were started during configuration.
  /// Used during testing to ensure old managers are properly cleaned up before reconfiguration.
  package func cleanupManagers() {
    watchConnectivityCoordinator?.stopAcceptingIdentityUpdates()
    identityController.invalidateLocalOperations()
    cancelStartupClientRefresh()
    invalidAuthRefreshTask?.cancel()
    invalidAuthRefreshTask = nil
    urlHandlingCoordinator.cancelAll()
    cancelEnvironmentRefreshTask()
    taskCoordinator?.cancelAll()
    sharedSessionSyncCoordinator?.deactivate()
    resetManagerStateForCleanup(finishAuthEventStreams: true)
    cacheManager?.shutdown()
    cacheManager = nil
    teardownNonCacheManagers()
  }

  private func cleanupManagersAndDrainCache(
    deleteSharedSessionOwnerSlot: Bool = true
  ) async {
    let watchConnectivityCoordinator = watchConnectivityCoordinator
    watchConnectivityCoordinator?.stopAcceptingIdentityUpdates()
    await identityController.invalidateAndDrainLocalOperations(
      through: dependencies.atomicIdentityIO
    )
    cancelStartupClientRefresh()
    invalidAuthRefreshTask?.cancel()
    await invalidAuthRefreshTask?.value
    invalidAuthRefreshTask = nil
    urlHandlingCoordinator.cancelAll()

    cancelEnvironmentRefreshTask()
    let sharedSessionSyncCoordinator = sharedSessionSyncCoordinator
    await sharedSessionSyncCoordinator?.shutdown(
      deleteOwnSlot: deleteSharedSessionOwnerSlot
    )
    // Stop SDK-owned tasks before draining the cache to prevent in-flight refreshes
    // from enqueuing new writes during the drain.
    await taskCoordinator?.cancelAllAndWait()
    await watchConnectivityCoordinator?.waitForIdentityPublications()

    resetManagerStateForCleanup(finishAuthEventStreams: false)
    await cacheManager?.shutdownAndDrain()
    cacheManager = nil
    teardownNonCacheManagers()
  }

  func canReuseSharedSessionOwnerSlot(
    with newDependencies: any Dependencies
  ) -> Bool {
    let currentOptions = dependencies.configurationManager.options
    let newOptions = newDependencies.configurationManager.options
    guard dependencies.configurationManager.publishableKey
      == newDependencies.configurationManager.publishableKey,
      currentOptions.sharedSessionSync != nil,
      newOptions.sharedSessionSync != nil,
      currentOptions.keychainConfig.service == newOptions.keychainConfig.service,
      currentOptions.keychainConfig.normalizedAccessGroup
      == newOptions.keychainConfig.normalizedAccessGroup,
      dependencies.sharedSessionOwnerIdentifier
      == newDependencies.sharedSessionOwnerIdentifier
    else {
      return false
    }

    return SharedSessionNamespace(
      frontendApiUrl: dependencies.configurationManager.frontendApiUrl,
      publishableKey: dependencies.configurationManager.publishableKey
    ) == SharedSessionNamespace(
      frontendApiUrl: newDependencies.configurationManager.frontendApiUrl,
      publishableKey: newDependencies.configurationManager.publishableKey
    )
  }

  private func resetManagerStateForCleanup(finishAuthEventStreams: Bool) {
    if finishAuthEventStreams {
      authEventEmitter.finish()
    }
    resetEnvironmentRefreshState()
    callbackContinuation = nil
    identityController.resetOrderingState()
  }

  private func cancelEnvironmentRefreshTask() {
    environmentRefreshTask?.cancel()
    environmentRefreshTask = nil
    environmentRefreshTaskID = nil
  }

  private func resetEnvironmentRefreshState() {
    cancelEnvironmentRefreshTask()
    environmentRefreshRevision = 0
  }

  private func teardownNonCacheManagers() {
    sessionPollingManager?.stopPolling()
    sessionPollingManager = nil
    lifecycleManager?.stopObserving()
    lifecycleManager = nil
    internalStateChanges.removeAllObservers()
    sharedSessionSyncCoordinator = nil
    watchConnectivityCoordinator = nil
    taskCoordinator?.cancelAll()
    taskCoordinator = nil
  }
}
