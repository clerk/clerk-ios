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

  private static var isRuntimeReconfigurationInProgress = false

  private struct ReconfigurationRollbackState {
    let configurationEpoch: ClerkConfigurationEpoch
    let dependencies: any Dependencies
    let lastAppliedClientResponseSequence: Int?
    let lastClientServerFetchDate: Date?
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

  /// The most recent network response sequence that updated the local client.
  private var lastAppliedClientResponseSequence: Int?

  /// Server timestamp from the response that last updated the local client.
  /// Used as a cross-device ordering key, since it comes from a
  /// single clock (the server) and advances on every API response.
  var lastClientServerFetchDate: Date?

  /// Changes when local device-token ownership changes.
  /// Client responses prepared before this value changes must not update state.
  private(set) var clientResponseGeneration: ClientResponseGeneration = .initial

  /// Shared refresh task used to coalesce invalid-auth recovery refreshes.
  private var invalidAuthRefreshTask: Task<Void, Never>?

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

  /// The main entry point for trusted-device credential operations.
  public var trustedDevices: TrustedDevices {
    TrustedDevices(
      trustedDeviceService: dependencies.trustedDeviceService,
      signInService: dependencies.signInService,
      keyManager: dependencies.trustedDeviceKeyManager,
      credentialStore: dependencies.trustedDeviceCredentialStore
    )
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

    performConfiguration(dependencies: dependencies)
  }

  /// Internal helper method that installs a prebuilt dependency container and starts managers.
  @MainActor
  func performConfiguration(dependencies: any Dependencies) {
    taskCoordinator?.cancelAll()
    internalStateChanges.removeAllObservers()
    sharedSessionSyncCoordinator = nil

    // Initialize task coordinator
    taskCoordinator = TaskCoordinator()

    self.dependencies = dependencies

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
    let cacheManager = CacheManager(coordinator: self, keychain: dependencies.keychain)
    self.cacheManager = cacheManager
    cacheManager.loadCachedData()

    if options.sharedSessionSync != nil {
      if let accessGroup = options.keychainConfig.accessGroup, !accessGroup.isEmpty {
        let coordinator = SharedSessionSyncCoordinator(
          keychainConfig: options.keychainConfig,
          clerk: self,
          keychain: dependencies.keychain
        )
        sharedSessionSyncCoordinator = coordinator
        internalStateChanges.addObserver(coordinator)
      } else {
        ClerkLogger.error(
          "Shared session sync requires a Keychain access group. Configure Clerk.Options.keychainConfig with the same service and accessGroup in every participating app."
        )
      }
    }

    // Set up watch connectivity coordinator only after cache hydration.
    // Restored cached state should not be versioned as a new local auth change.
    if options.watchConnectivityEnabled {
      internalStateChanges.addObserver(WatchConnectivityCoordinator())
    }

    // Fire and forget: fetch fresh client and environment from API
    let retryPolicy = Self.startupRefreshRetryPolicy
    taskCoordinator?.task { @MainActor [weak self] in
      do {
        guard let self else { return }
        async let client = retryingOperation(
          policy: retryPolicy,
          operationName: "client refresh"
        ) {
          try await self.refreshClient()
        }
        async let environment = retryingOperation(
          policy: retryPolicy,
          operationName: "environment refresh"
        ) {
          try await self.refreshEnvironment()
        }

        _ = try await environment
        _ = try await client
      } catch is CancellationError {
        return
      } catch {
        ClerkLogger.logError(error, message: "Failed to load client or environment")
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

  /// Reconfigures the shared Clerk instance with a new publishable key and options.
  ///
  /// This method validates the new configuration, clears local Clerk state, and then
  /// installs the new configuration on the existing shared instance. Any user currently
  /// signed in should be expected to sign in again after reconfiguration.
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
      let nextEpoch = existing.nextConfigurationEpoch
      let newDependencies = try DependencyContainer(
        publishableKey: publishableKey,
        options: options,
        runtimeScope: .init(epoch: nextEpoch, runtimeState: existing.runtimeState)
      )
      let oldKeychain = existing.dependencies.keychain
      let newKeychain = newDependencies.keychain
      let rollbackState = existing.captureReconfigurationRollbackState()

      try clearAllKeychainItemsStrictly(in: newKeychain)

      existing.setConfigurationEpoch(to: nextEpoch)
      await existing.cleanupManagersAndDrainCache()

      do {
        try clearAllKeychainItemsStrictly(in: oldKeychain)
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
      runtimeScope: clerk.runtimeScope
    )

    try clearAllKeychainItemsStrictly(in: newDependencies.keychain)

    clerk.performConfiguration(dependencies: newDependencies)
    _shared = clerk
    return clerk
  }

  @MainActor
  package static func resetSharedInstanceForTesting() async {
    guard EnvironmentDetection.isRunningInTests else {
      return
    }

    guard let shared = _shared else {
      return
    }

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
    let runtime = runtimeScope
    let clientResponseGeneration = clientResponseGeneration
    let response = try await dependencies.clientService.getResponse(skipClientId: skipClientId)
    try runtime.validateStableRuntime()
    applyResponseClient(
      response.client,
      responseSequence: response.requestSequence,
      serverDate: response.serverDate,
      clientResponseGeneration: clientResponseGeneration
    )
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

    client = nil
    environment = nil
    sessionsByUserId = [:]
    WebAuthentication.cancelCurrentSession()

    #if canImport(AuthenticationServices) && !os(watchOS)
    PasskeyHelper.cancelCurrentAuthorization()
    #endif
  }
}

extension Clerk: CacheCoordinator {
  func setClientIfNeeded(_ client: Client?, serverFetchDate: Date?) {
    guard self.client == nil else { return }
    if let serverFetchDate {
      lastClientServerFetchDate = serverFetchDate
    }
    self.client = client
  }

  func setServerFetchDateIfNeeded(_ date: Date) {
    guard client == nil, lastClientServerFetchDate == nil else { return }
    lastClientServerFetchDate = date
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
      lastAppliedClientResponseSequence: lastAppliedClientResponseSequence,
      lastClientServerFetchDate: lastClientServerFetchDate
    )
  }

  private func restoreAfterFailedReconfiguration(_ state: ReconfigurationRollbackState) {
    setConfigurationEpoch(to: state.configurationEpoch)
    lastAppliedClientResponseSequence = state.lastAppliedClientResponseSequence
    lastClientServerFetchDate = state.lastClientServerFetchDate
    performConfiguration(dependencies: state.dependencies)
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

  func applyResponseClient(
    _ incoming: Client?,
    responseSequence: Int? = nil,
    serverDate: Date? = nil,
    clientResponseGeneration: ClientResponseGeneration? = nil
  ) {
    if let clientResponseGeneration, clientResponseGeneration != self.clientResponseGeneration {
      ClerkLogger.debug(
        "Ignoring client response from stale device token generation. Current generation: \(self.clientResponseGeneration), incoming generation: \(clientResponseGeneration)"
      )
      return
    }

    if let responseSequence {
      if let lastAppliedClientResponseSequence,
         responseSequence <= lastAppliedClientResponseSequence,
         !responseIsNewerThanCurrent(incoming, serverDate: serverDate)
      {
        ClerkLogger.debug(
          "Ignoring stale client response. Current sequence: \(lastAppliedClientResponseSequence), incoming sequence: \(responseSequence)"
        )
        return
      }

      lastAppliedClientResponseSequence = max(lastAppliedClientResponseSequence ?? responseSequence, responseSequence)
    }

    if let serverDate {
      lastClientServerFetchDate = serverDate
    }
    client = incoming
  }

  private func responseIsNewerThanCurrent(_ incoming: Client?, serverDate: Date?) -> Bool {
    guard let serverDate, let lastClientServerFetchDate else {
      return false
    }

    if serverDate > lastClientServerFetchDate {
      return true
    }

    guard serverDate == lastClientServerFetchDate, let incoming, let client else {
      return false
    }

    return incoming.updatedAt > client.updatedAt
  }

  func fenceClientResponsesAfterDeviceTokenChange() {
    clientResponseGeneration = clientResponseGeneration.next()
    lastAppliedClientResponseSequence = nil
  }

  func clearCachedClientStateAfterDeviceTokenChange() {
    fenceClientResponsesAfterDeviceTokenChange()
    lastClientServerFetchDate = nil
    client = nil

    for key in [
      ClerkKeychainKey.cachedClient,
      .cachedClientServerDate,
      .cachedEnvironment,
    ] {
      do {
        try dependencies.keychain.deleteItem(forKey: key.rawValue)
      } catch {
        ClerkLogger.logError(error, message: "Failed to clear cached Clerk data after device token update")
      }
    }
  }

  /// Cleans up managers that were started during configuration.
  /// Used during testing to ensure old managers are properly cleaned up before reconfiguration.
  package func cleanupManagers() {
    invalidAuthRefreshTask?.cancel()
    invalidAuthRefreshTask = nil
    urlHandlingCoordinator.cancelAll()
    cancelEnvironmentRefreshTask()
    taskCoordinator?.cancelAll()
    resetManagerStateForCleanup(finishAuthEventStreams: true)
    cacheManager?.shutdown()
    cacheManager = nil
    teardownNonCacheManagers()
  }

  private func cleanupManagersAndDrainCache() async {
    invalidAuthRefreshTask?.cancel()
    await invalidAuthRefreshTask?.value
    invalidAuthRefreshTask = nil
    urlHandlingCoordinator.cancelAll()

    cancelEnvironmentRefreshTask()
    // Stop SDK-owned tasks before draining the cache to prevent in-flight refreshes
    // from enqueuing new writes during the drain.
    await taskCoordinator?.cancelAllAndWait()

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
    lastAppliedClientResponseSequence = nil
    lastClientServerFetchDate = nil
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
    taskCoordinator?.cancelAll()
    taskCoordinator = nil
  }
}
