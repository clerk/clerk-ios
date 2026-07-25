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
  private static var runtimeReconfigurationWaiters: [CheckedContinuation<Void, Never>] = []

  /// A getter to see if the Clerk object is ready for use or not.
  /// Returns true when persisted identity is safe to use and both environment
  /// and client are loaded.
  public var isLoaded: Bool {
    persistenceStatus.readiness == .ready
      && environment != nil
      && client != nil
  }

  /// Availability and readiness of Clerk's identity persistence and optional
  /// cross-app session transport.
  public internal(set) var persistenceStatus = PersistenceStatus(
    identityStorage: .durable,
    sharedSession: .disabled,
    readiness: .ready
  )

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

  /// The client that has crossed an authoritative persistence or response boundary.
  var authoritativeClient: Client? {
    identityController.authoritativeClient
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

  var isWatchConnectivityInstalled: Bool {
    watchConnectivityCoordinator != nil
  }

  /// Coalesces overlapping public Keychain clears so persistence remains frozen
  /// until the single clear transaction has completed.
  var keychainClearTask: Task<Void, Error>?

  /// Persists an explicit clear outside Keychain so the obligation survives
  /// process termination while durable identity storage is unavailable.
  @ObservationIgnored
  var appContainerIdentityClearIntentStore =
    AppContainerIdentityClearIntentStoreFactory.makeDefault()

  /// Clears the exact durable topology captured by an app-container intent
  /// without installing or promoting those dependencies into the runtime.
  @ObservationIgnored
  var appContainerIdentityClearRecovery =
    AppContainerIdentityClearRecovery()

  /// Keeps authentication operations on one persistence runtime across
  /// suspension points.
  @ObservationIgnored
  lazy var identityPersistenceOperationCoordinator =
    IdentityPersistenceOperationCoordinator(clerk: self)

  var identityPersistenceClearPending: Bool {
    identityPersistenceOperationCoordinator.isClearPending
  }

  /// Shared generation observed when this app entered local-durable mode.
  /// Local mutations retain this base so later transport recovery can resolve
  /// concurrent sibling changes without assuming either side always wins.
  var sharedSessionDegradationBaseGeneration: UInt64?

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
  private func recoverAppContainerIdentityClearStrictlyIfNeeded(
    protecting currentDependencies: any Dependencies
  ) throws -> Bool {
    guard let intent = try appContainerIdentityClearIntentStore.load() else {
      return false
    }
    try recoverAppContainerIdentityClear(
      intent,
      protecting: currentDependencies
    )
    try appContainerIdentityClearIntentStore.remove(
      matching: intent.transactionID
    )
    return true
  }

  /// Installs dependencies whose pending clear recovery has already been checked.
  @MainActor
  func installConfiguration(
    dependencies: any Dependencies,
    bootstrapBlockReason: PersistenceBlockReason? = nil
  ) {
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
    sharedSessionDegradationBaseGeneration = nil
    let initialSharedCapability: SharedSessionCapability = if options.sharedSessionSync == nil {
      .disabled
    } else if case .volatile(let failure) =
      dependencies.identityPersistenceCapability
    {
      .unavailable(failure)
    } else {
      .unavailable(.temporarilyUnavailable)
    }
    identityPersistenceOperationCoordinator.reset(
      identityCapability: dependencies.identityPersistenceCapability,
      sharedSessionCapability: initialSharedCapability
    )
    let bootstrapOwnership =
      identityPersistenceOperationCoordinator.beginBootstrap(
        epoch: configurationEpoch
      )
    let durableIdentityPersistenceIsAvailable =
      !dependencies.usesVolatileIdentityPersistence
    let usesSharedSessionSync = options.sharedSessionSync != nil
      && durableIdentityPersistenceIsAvailable

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

    if let bootstrapBlockReason {
      cacheManager.loadCachedData(hydrateIdentity: false)
      identityPersistenceOperationCoordinator.block(
        bootstrapOwnership,
        reason: bootstrapBlockReason
      )
      startEnvironmentRefresh()
      return
    }

    let initialSharedSessionReconciliation: Task<Bool, Never>?
    if usesSharedSessionSync {
      cacheManager.loadCachedData(hydrateIdentity: false)
      if dependencies.shouldHydrateProvisionalLegacyClient {
        cacheManager.loadProvisionalLegacyClientForPresentation()
      }
      initialSharedSessionReconciliation = startSharedSessionSyncIfNeeded(
        dependencies: dependencies,
        cacheManager: cacheManager,
        bootstrapOwnership: bootstrapOwnership
      )
    } else {
      cacheManager.loadCachedData()
      identityPersistenceOperationCoordinator.setSharedSessionCapability(
        initialSharedCapability
      )
      identityPersistenceOperationCoordinator.finish(bootstrapOwnership)
      installWatchConnectivityIfAvailable()
      initialSharedSessionReconciliation = nil
    }

    startEnvironmentRefresh()
    startStartupClientRefreshIfNeeded(after: initialSharedSessionReconciliation)
  }

  private func startEnvironmentRefresh() {
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
  }

  func installWatchConnectivityIfAvailable() {
    guard options.watchConnectivityEnabled,
          identityPersistenceOperationCoordinator.isIdentityReady,
          case .durable =
          identityPersistenceOperationCoordinator.identityCapability,
          watchConnectivityCoordinator == nil
    else {
      return
    }
    let coordinator = WatchConnectivityCoordinator()
    watchConnectivityCoordinator = coordinator
    internalStateChanges.addObserver(coordinator)
  }

  func suspendWatchConnectivityForPersistenceTransition() {
    guard let coordinator = watchConnectivityCoordinator else { return }
    coordinator.stopAcceptingIdentityUpdates()
    internalStateChanges.removeObserver(coordinator)
    watchConnectivityCoordinator = nil
  }

  func resumeWatchConnectivityAfterPersistenceTransition() {
    installWatchConnectivityIfAvailable()
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

  /// Installs an isolated instance without starting production managers.
  ///
  /// SwiftUI previews use this path so their mock state never depends on
  /// production persistence, lifecycle, networking, Watch, or shared-session
  /// setup.
  @MainActor
  static func configureForPreview(
    dependencies makeDependencies: (Clerk) -> any Dependencies
  ) -> Clerk {
    if let existing = _shared {
      existing.cleanupManagers()
      _shared = nil
    }

    let clerk = Clerk()
    clerk.dependencies = makeDependencies(clerk)
    _shared = clerk
    return clerk
  }

  /// Configures the shared instance with isolated persistence for SDK tests.
  @MainActor
  @discardableResult
  static func configureForTesting(
    publishableKey: String,
    options: Clerk.Options = .init(),
    keychainStorage: any KeychainStorage
  ) throws -> Clerk {
    guard EnvironmentDetection.isRunningInTests else {
      throw ClerkClientError(
        message: "Isolated Clerk configuration is only available while running tests."
      )
    }

    if let existing = _shared {
      existing.cleanupManagers()
      _shared = nil
    }

    let clerk = Clerk()
    let dependencies = try DependencyContainer(
      publishableKey: publishableKey,
      options: options,
      runtimeScope: clerk.runtimeScope,
      persistentAdoptionEnabledOverride: false,
      keychainStorageOverride: keychainStorage
    )
    try clerk.performConfiguration(dependencies: dependencies)
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
  /// instance without going through the fallback ``Clerk/shared`` getter. This initial
  /// reconfiguration remains strict because it promises to clear persisted credentials:
  /// it throws when durable storage cannot be reached. Use ``configure(publishableKey:options:)``
  /// for resilient initial launch with isolated in-memory fallback.
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
    if let existing = _shared {
      try await existing.keychainClearTask?.value
      if existing.identityPersistenceClearPending {
        try await startKeychainClearIfNeeded(for: existing).value
      }
    }

    try beginRuntimeReconfiguration()
    defer { endRuntimeReconfiguration() }

    if let existing = _shared {
      return try await existing.performReconfiguration(
        publishableKey: publishableKey,
        options: options
      )
    }

    return try await configureNewSharedInstance(
      publishableKey: publishableKey,
      options: options
    )
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
    await Clerk.waitForRuntimeReconfigurationIfNeeded()
    guard let route = try ClerkURLRoute(url: url, redirectUrl: options.redirectConfig.redirectUrl) else {
      return false
    }

    try await auth.handle(route)
    return true
  }
}

extension Clerk: CacheCoordinator {
  func hydrateIdentityIfNeeded(_ identity: ClerkIdentitySnapshot) {
    identityController.hydrateAtomicIdentityIfNeeded(identity)
  }

  func setClientIfNeeded(_ client: Client?, serverFetchDate: Date?) {
    identityController.hydrateLegacyClientIfNeeded(client, serverDate: serverFetchDate)
  }

  func setProvisionalClientIfNeeded(_ client: Client?) {
    identityController.hydrateProvisionalLegacyClientIfNeeded(client)
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

    if identityPersistenceClearPending {
      do {
        try await Self.startKeychainClearIfNeeded(for: self).value
      } catch {
        ClerkLogger.logError(
          error,
          message: "Clerk identity storage is still unavailable. The pending identity clear will retry on the next foreground."
        )
      }
      return
    }
    if case .blocked = persistenceStatus.readiness {
      return
    }

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
    let waiters = runtimeReconfigurationWaiters
    runtimeReconfigurationWaiters.removeAll()
    waiters.forEach { $0.resume() }
  }

  @MainActor
  static var runtimeReconfigurationIsInProgress: Bool {
    isRuntimeReconfigurationInProgress
  }

  @MainActor
  static func waitForRuntimeReconfigurationIfNeeded() async {
    guard isRuntimeReconfigurationInProgress else { return }
    await withCheckedContinuation {
      runtimeReconfigurationWaiters.append($0)
    }
  }

  @MainActor
  static func requireStableRuntime() throws -> ClerkRuntimeScope {
    guard !isRuntimeReconfigurationInProgress else {
      throw CancellationError()
    }

    guard let shared = _shared else {
      throw ClerkClientError(message: "Clerk must be configured before getting a session token.")
    }

    try shared.identityPersistenceOperationCoordinator
      .requireIdentityOperationsAvailable()
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

  private static func configureNewSharedInstance(
    publishableKey: String,
    options: Clerk.Options
  ) async throws -> Clerk {
    let clerk = Clerk()
    func makeDependencies() throws -> DependencyContainer {
      try DependencyContainer(
        publishableKey: publishableKey,
        options: options,
        runtimeScope: clerk.runtimeScope,
        deferSharedSessionAdoption: true
      )
    }

    var dependencies = try makeDependencies()
    if try clerk.recoverAppContainerIdentityClearStrictlyIfNeeded(
      protecting: dependencies
    ) {
      dependencies = try makeDependencies()
    }
    try SharedSessionOwnerSlotClearRecovery.recoverIfNeeded(
      in: dependencies.sharedSessionOwnerSlotClearRecovery
    )
    try dependencies.probeLocalIdentityPersistence()
    try await clearLocalClerkStorageStrictly(in: dependencies)
    try dependencies
      .markSharedSessionAdoptedWithoutMigratingCredentialsIfNeeded()
    try dependencies.discardPendingPublicationWhenSharedSyncDisabled()
    clerk.installConfiguration(dependencies: dependencies)
    _shared = clerk
    return clerk
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
    identityPersistenceOperationCoordinator.cancelActiveTransition()
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

  func cleanupManagersAndDrainCache(
    deleteSharedSessionOwnerSlot: Bool = true,
    cancelPersistenceTransition: Bool = true
  ) async {
    if cancelPersistenceTransition {
      identityPersistenceOperationCoordinator.cancelActiveTransition()
    }
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
