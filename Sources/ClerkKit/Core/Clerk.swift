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

  /// A getter to see if the Clerk object is ready for use or not.
  /// Returns true when both environment and client are loaded.
  public var isLoaded: Bool {
    environment != nil && client != nil
  }

  /// A getter to see if a Clerk instance is running in production or development mode.
  public var instanceType: InstanceEnvironmentType {
    dependencies.configurationManager.instanceType
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

      // Sync to watch app if enabled (sync both when client is set and when it's cleared)
      watchConnectivityCoordinator?.sync()
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

  /// A dictionary of a user's active sessions on all devices.
  public internal(set) var sessionsByUserId: [String: [Session]] = [:]

  /// The most recent network response sequence that updated the local client.
  private var lastAppliedClientResponseSequence: Int?

  /// Server timestamp from the response that last updated the local client.
  /// Used as a cross-device ordering key for watch sync, since it comes from a
  /// single clock (the server) and advances on every API response.
  private(set) var lastClientServerFetchDate: Date?

  /// Shared refresh task used to coalesce invalid-auth recovery refreshes.
  private var invalidAuthRefreshTask: Task<Void, Never>?

  /// Shared refresh task used to coalesce watch-sync-triggered refreshes.
  private var watchSyncRefreshTask: Task<Void, Never>?

  /// The publishable key from your Clerk Dashboard, used to connect to Clerk.
  public var publishableKey: String {
    dependencies.configurationManager.publishableKey
  }

  /// The Clerk environment for the instance.
  public internal(set) var environment: Environment? {
    didSet {
      if let environment {
        cacheManager?.saveEnvironment(environment)
        // Sync to watch app if enabled
        watchConnectivityCoordinator?.sync()
      }
    }
  }

  /// The configuration options for this Clerk instance.
  public var options: Clerk.Options {
    dependencies.configurationManager.options
  }

  /// Coordinates task lifecycle and cleanup.
  private var taskCoordinator: TaskCoordinator?

  /// Frontend API URL.
  var frontendApiUrl: String {
    dependencies.configurationManager.frontendApiUrl
  }

  // MARK: - Lifecycle Managers

  // These managers coordinate Clerk-specific lifecycle concerns and require Clerk as a dependency.

  /// Manages caching of client and environment data.
  private var cacheManager: CacheManager?

  /// Manages periodic polling of session tokens to keep them refreshed.
  private var sessionPollingManager: SessionPollingManager?

  /// Manages app lifecycle notifications and coordinates foreground/background transitions.
  private var lifecycleManager: LifecycleManager?

  /// Coordinates watch connectivity syncing.
  private var watchConnectivityCoordinator: WatchConnectivityCoordinator?

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
      apiClient: dependencies.apiClient,
      magicLinkStore: dependencies.magicLinkStore,
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
        options: .init()
      )
    } catch {
      // This should never happen, but handle it just in case
      assertionFailure("Failed to create temporary dependency container: \(error.localizedDescription)")
      if let fallbackDependencies = try? DependencyContainer(publishableKey: "", options: .init()) {
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
  package func performConfiguration(publishableKey: String, options: Clerk.Options) throws {
    // Initialize task coordinator
    taskCoordinator = TaskCoordinator()

    // Create dependency container (which creates and configures ConfigurationManager internally)
    dependencies = try DependencyContainer(
      publishableKey: publishableKey,
      options: options
    )

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

    // Set up watch connectivity coordinator only if enabled
    if options.watchConnectivityEnabled {
      watchConnectivityCoordinator = WatchConnectivityCoordinator()
    }

    // Set up cache manager and load cached data synchronously
    let cacheManager = CacheManager(coordinator: self, keychain: dependencies.keychain)
    self.cacheManager = cacheManager
    cacheManager.loadCachedData()

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

  /// Refreshes the current client from the API.
  @discardableResult
  public func refreshClient() async throws -> Client? {
    let response = try await dependencies.clientService.getResponse()
    applyResponseClient(
      response.client,
      responseSequence: response.requestSequence,
      serverDate: response.serverDate
    )
    return client
  }

  /// Refreshes the current environment from the API.
  @discardableResult
  public func refreshEnvironment() async throws -> Environment {
    let environment = try await dependencies.environmentService.get()
    self.environment = environment
    return environment
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
    guard let route = try ClerkURLRoute(url: url) else {
      return false
    }

    _ = try await auth.handle(route)

    return true
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

    // Sync authentication state to watch app if enabled
    watchConnectivityCoordinator?.sync()

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
  func refreshClientAfterInvalidAuth() async {
    if let invalidAuthRefreshTask {
      await invalidAuthRefreshTask.value
      return
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
    await task.value
  }

  func applyResponseClient(_ incoming: Client?, responseSequence: Int? = nil, serverDate: Date? = nil) {
    if let responseSequence {
      if let lastAppliedClientResponseSequence,
         responseSequence <= lastAppliedClientResponseSequence
      {
        ClerkLogger.debug(
          "Ignoring stale client response. Current sequence: \(lastAppliedClientResponseSequence), incoming sequence: \(responseSequence)"
        )
        return
      }

      lastAppliedClientResponseSequence = responseSequence
    }

    if let serverDate {
      lastClientServerFetchDate = serverDate
    }
    client = incoming
  }

  func applyWatchSyncedClient(
    _ incoming: Client?,
    incomingServerFetchDate: Date?,
    incomingIsAuthoritative: Bool
  ) {
    if incomingIsAuthoritative {
      if let incomingServerFetchDate {
        lastClientServerFetchDate = incomingServerFetchDate
      }
      client = incoming
      return
    }

    // Non-authoritative (watch → phone):
    // Compare server fetch dates when available — both come from the same server
    // clock, so there is no cross-device skew. The device whose client was confirmed
    // by the server more recently has the fresher state.
    // A nil incoming (missing or undecodable client field) is never accepted
    // non-authoritatively since there is no client data to apply.
    if let incoming, let incomingServerFetchDate, let lastClientServerFetchDate,
       incomingServerFetchDate > lastClientServerFetchDate
    {
      self.lastClientServerFetchDate = incomingServerFetchDate
      if incoming != client {
        client = incoming
      } else {
        cacheManager?.saveServerFetchDate(incomingServerFetchDate)
      }
      return
    }

    // Phone has a client or a server-confirmed state to protect — defer to server.
    if client != nil || lastClientServerFetchDate != nil {
      scheduleWatchSyncRefresh()
      return
    }

    // Phone has no client and no server-confirmed state at all
    // (e.g. fresh install, cold launch with no cached data) —
    // accept watch state as provisional.
    if let incoming {
      lastClientServerFetchDate = incomingServerFetchDate
      client = incoming
      scheduleWatchSyncRefresh()
    }
  }

  private func scheduleWatchSyncRefresh() {
    guard watchSyncRefreshTask == nil else { return }

    watchSyncRefreshTask = Task { [weak self] in
      defer { self?.watchSyncRefreshTask = nil }
      do {
        try await self?.refreshClient()
      } catch {
        ClerkLogger.logError(error, message: "Failed to refresh client after watch sync")
      }
    }
  }

  func storeReceivedDeviceToken(_ token: String) {
    do {
      try dependencies.keychain.set(token, forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
      watchConnectivityCoordinator?.sync()
    } catch {
      ClerkLogger.logError(error, message: "Failed to save device token to keychain")
    }
  }

  /// Cleans up managers that were started during configuration.
  /// Used during testing to ensure old managers are properly cleaned up before reconfiguration.
  package func cleanupManagers() {
    invalidAuthRefreshTask?.cancel()
    invalidAuthRefreshTask = nil
    watchSyncRefreshTask?.cancel()
    watchSyncRefreshTask = nil
    urlHandlingCoordinator.cancelAll()
    resetManagerStateForCleanup()
    cacheManager?.shutdown()
    cacheManager = nil
    teardownNonCacheManagers()
  }

  package func cleanupManagersAndDrainCache() async {
    invalidAuthRefreshTask?.cancel()
    await invalidAuthRefreshTask?.value
    invalidAuthRefreshTask = nil
    watchSyncRefreshTask?.cancel()
    await watchSyncRefreshTask?.value
    watchSyncRefreshTask = nil
    urlHandlingCoordinator.cancelAll()

    // Cancel task coordinator tasks before draining the cache to prevent
    // in-flight refreshes from enqueuing new writes during the drain.
    taskCoordinator?.cancelAll()

    resetManagerStateForCleanup()
    await cacheManager?.shutdownAndDrain()
    cacheManager = nil
    teardownNonCacheManagers()
  }

  private func resetManagerStateForCleanup() {
    authEventEmitter.finish()
    callbackContinuation = nil
    lastAppliedClientResponseSequence = nil
    lastClientServerFetchDate = nil
  }

  private func teardownNonCacheManagers() {
    sessionPollingManager?.stopPolling()
    sessionPollingManager = nil
    lifecycleManager?.stopObserving()
    lifecycleManager = nil
    watchConnectivityCoordinator = nil
    taskCoordinator?.cancelAll()
    taskCoordinator = nil
  }
}
