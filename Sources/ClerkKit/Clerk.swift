//
//  Clerk.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

/**
 This is the main entrypoint class for the clerk package. It contains a number of methods and properties for interacting with the Clerk API.
 */
@MainActor
@Observable
public final class Clerk {
  /// The shared Clerk instance.
  ///
  /// Accessing this property before calling `Clerk.configure(publishableKey:options:)` will result in a precondition failure.
  public static var shared: Clerk {
    guard let instance = _shared else {
      preconditionFailure("Clerk has not been configured. Call Clerk.configure(publishableKey:options:) before accessing Clerk.shared")
    }
    return instance
  }

  /// Private shared instance that is set during configuration.
  private static var _shared: Clerk?

  /// A getter to see if the Clerk object is ready for use or not.
  public private(set) var isLoaded: Bool = false

  /// A getter to see if a Clerk instance is running in production or development mode.
  public var instanceType: InstanceEnvironmentType {
    dependencies.configurationManager.instanceType
  }

  /// The Client object for the current device.
  public internal(set) var client: Client? {
    didSet {
      if let client {
        cacheManager?.saveClient(client)
        dependencies.sessionStatusLogger.logPendingSessionStatusIfNeeded(previousClient: oldValue, currentClient: client)
      } else {
        cacheManager?.deleteClient()
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

  /// The currently active Session, which is guaranteed to be one of the sessions in Client.sessions. If there is no active session, this field will be nil.
  public var session: Session? {
    guard let client else { return nil }
    return client.activeSessions.first(where: { $0.id == client.lastActiveSessionId })
  }

  /// A shortcut to Session.user which holds the currently active User object. If the session is nil, the user field will match.
  public var user: User? {
    session?.user
  }

  /// A dictionary of a user's active sessions on all devices.
  public internal(set) var sessionsByUserId: [String: [Session]] = [:]

  /// The publishable key from your Clerk Dashboard, used to connect to Clerk.
  public var publishableKey: String {
    dependencies.configurationManager.publishableKey
  }

  /// The event emitter for auth events.
  public let authEventEmitter = EventEmitter<AuthEvent>()

  /// The event emitter for general Clerk events.
  let clerkEventEmitter = EventEmitter<ClerkEvent>()

  /// The Clerk environment for the instance.
  public internal(set) var environment = Environment() {
    didSet {
      cacheManager?.saveEnvironment(environment)

      // Sync to watch app if enabled
      watchConnectivityCoordinator?.sync()
    }
  }

  /// The configuration options for this Clerk instance.
  public var options: Clerk.ClerkOptions {
    dependencies.configurationManager.options
  }

  /// Coordinates task lifecycle and cleanup.
  private var taskCoordinator: TaskCoordinator?

  /// Task that coordinates cached data loading during initialization.
  /// This is set during `configure()` and awaited during `load()`.
  /// Automatically tracked via TaskCoordinator for cleanup.
  private var cachedDataLoadingTask: Task<Void, Never>? {
    didSet {
      if let task = cachedDataLoadingTask {
        taskCoordinator?.track(task)
      }
    }
  }

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
  package var watchConnectivityCoordinator: WatchConnectivityCoordinator?

  /// Task that listens for auth events and handles them.
  private var authEventListenerTask: Task<Void, Never>?

  /// Task that listens for general Clerk events and handles them.
  private var clerkEventListenerTask: Task<Void, Never>?

  /// Dependency container holding all SDK dependencies.
  var dependencies: any Dependencies

  /// Clerk service for handling sign out and session management operations.
  private var clerkService: any ClerkServiceProtocol {
    dependencies.clerkService
  }

  /// Proxy configuration derived from `proxyUrl`, if present.
  var proxyConfiguration: ProxyConfiguration? {
    dependencies.configurationManager.proxyConfiguration
  }

  package init() {
    // Create temporary container - will be replaced during configure with proper values
    // Empty publishableKey is handled gracefully by DependencyContainer
    let tempOptions = Clerk.ClerkOptions()
    do {
      dependencies = try DependencyContainer(
        publishableKey: "",
        options: tempOptions
      )
    } catch {
      // This should never happen, but handle it just in case
      preconditionFailure("Failed to create temporary dependency container: \(error.localizedDescription)")
    }
  }
}

public extension Clerk {
  /// Internal helper method that performs the actual configuration work.
  @MainActor
  package func performConfiguration(publishableKey: String, options: Clerk.ClerkOptions) throws {
    // Initialize task coordinator
    taskCoordinator = TaskCoordinator()

    // Create dependency container (which creates and configures ConfigurationManager internally)
    dependencies = try DependencyContainer(
      publishableKey: publishableKey,
      options: options
    )

    // Set up session polling and lifecycle management
    sessionPollingManager = SessionPollingManager(sessionProvider: self)
    lifecycleManager = LifecycleManager(handler: self)
    sessionPollingManager?.startPolling()
    lifecycleManager?.startObserving()

    // Set up event listeners
    startAuthEventListener()
    startClerkEventListener()

    // Set up watch connectivity coordinator only if enabled
    if options.watchConnectivityEnabled {
      watchConnectivityCoordinator = WatchConnectivityCoordinator(
        keychain: dependencies.keychain,
        enabled: true
      )
      watchConnectivityCoordinator?.start()
    }

    // Set up cache manager and load cached data asynchronously
    let cacheManager = CacheManager(coordinator: self, keychain: dependencies.keychain)
    self.cacheManager = cacheManager

    // Load cached data asynchronously (don't block on this)
    cachedDataLoadingTask = Task { @MainActor in
      await cacheManager.loadCachedData()
    }
  }

  /// Configures the shared Clerk instance.
  ///
  /// This method must be called before accessing `Clerk.shared`. If called multiple times,
  /// a warning will be logged and subsequent calls will be ignored.
  ///
  /// In test environments, reconfiguration is allowed to support test isolation.
  ///
  /// This method:
  /// 1. Sets up configuration (API client, options, etc.)
  /// 2. Sets up lifecycle and session polling managers
  /// 3. Starts loading cached client and environment data from keychain (asynchronously)
  /// 4. Sets the shared instance
  ///
  /// - Parameters:
  ///     - publishableKey: The publishable key from your Clerk Dashboard, used to connect to Clerk.
  ///     - options: Configuration options for the Clerk instance. Defaults to a new `ClerkOptions` instance.
  /// - Returns: The configured Clerk instance.
  @MainActor
  @discardableResult
  static func configure(
    publishableKey: String,
    options: Clerk.ClerkOptions = .init()
  ) -> Clerk {
    // Allow reconfiguration in test environments for test isolation
    if let existing = _shared {
      if EnvironmentDetection.isRunningInTests {
        // Reset the shared instance to allow reconfiguration in tests
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
      preconditionFailure("Failed to configure Clerk: \(error.localizedDescription)")
    }

    _shared = clerk
    return clerk
  }

  /// Loads all necessary environment configuration and instance settings from the Frontend API.
  /// It is absolutely necessary to call this method before using the Clerk object in your code.
  func load() async throws {
    // Ensure cached data loading has completed
    await cachedDataLoadingTask?.value

    // Ensure Clerk has been configured
    guard cachedDataLoadingTask != nil else {
      throw ClerkInitializationError.initializationFailed(
        underlyingError: ClerkClientError(message: "Clerk must be configured before calling load(). Call Clerk.configure() first.")
      )
    }

    do {
      // Fetch client and environment concurrently
      // Both of these are automatically applied to the shared instance:
      async let client = Client.get()  // via middleware
      async let environment = Environment.get()  // via the function itself

      // Wait for both to complete - if either fails, we exit early
      // since both are required for the SDK to work properly
      // If client fails, environment will be cancelled automatically
      let env = try await environment
      _ = try await client
      attestDeviceIfNeeded(environment: env)

      // Sync authentication state to watch app after initial load if enabled
      watchConnectivityCoordinator?.sync()

      isLoaded = true
    } catch {
      // Wrap errors in appropriate ClerkInitializationError
      if let error = error as? ClerkInitializationError {
        throw error
      } else {
        // Since we're fetching concurrently, we can't easily tell which one failed
        // So we'll use a generic initialization error
        throw ClerkInitializationError.initializationFailed(underlyingError: error)
      }
    }
  }

  /// Signs out the active user.
  ///
  /// - In a **multi-session** application: Signs out the active user from all sessions.
  /// - In a **single-session** context: Signs out the active user from the current session.
  /// - You can specify a specific session to sign out by passing the `sessionId` parameter.
  ///
  /// - Parameter sessionId: An optional session ID to specify a particular session to sign out.
  ///   Useful for multi-session applications.
  ///
  /// - Throws: An error if the sign-out process fails.
  ///
  /// - Example:
  /// ```swift
  /// try await clerk.signOut()
  /// ```
  func signOut(sessionId: String? = nil) async throws {
    try await clerkService.signOut(sessionId: sessionId)
  }

  /// A method used to set the active session.
  ///
  /// Useful for multi-session applications.
  ///
  /// - Parameter sessionId: The session ID to be set as active.
  /// - Parameter organizationId: The organization ID to be set as active in the current session. If nil, the currently active organization is removed as active.
  func setActive(sessionId: String, organizationId: String? = nil) async throws {
    try await clerkService.setActive(sessionId: sessionId, organizationId: organizationId)
  }
}

extension Clerk: CacheCoordinator {
  func setClientIfNeeded(_ client: Client?) {
    guard self.client == nil else { return }
    self.client = client
  }

  func setEnvironmentIfNeeded(_ environment: Clerk.Environment) {
    guard self.environment.isEmpty else { return }
    self.environment = environment
  }

  var hasClient: Bool {
    client != nil
  }

  var isEnvironmentEmpty: Bool {
    environment.isEmpty
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
    taskCoordinator?.task {
      do {
        try await Client.get()
      } catch {
        ClerkLogger.logError(error, message: "Failed to refresh client on foreground")
      }
    }

    taskCoordinator?.task {
      do {
        _ = try await Environment.get()
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
  private func attestDeviceIfNeeded(environment: Environment) {
    if !AppAttestHelper.hasKeyId, [.onboarding, .enforced].contains(environment.fraudSettings?.native.deviceAttestationMode) {
      taskCoordinator?.task(priority: .background) {
        do {
          try await AppAttestHelper.performDeviceAttestation()
        } catch {
          ClerkLogger.logError(error, message: "Device attestation failed")
        }
      }
    }
  }

  /// Starts listening for auth events and handles them.
  private func startAuthEventListener() {
    authEventListenerTask = Task { @MainActor [weak self] in
      guard let self else { return }
      for await _ in authEventEmitter.events {
        // Process auth events synchronously since we're already on MainActor
        // Auth events are handled elsewhere (e.g., by ClerkAuthEventEmitterResponseMiddleware)
      }
    }
  }

  /// Starts listening for general Clerk events and handles them.
  private func startClerkEventListener() {
    clerkEventListenerTask = Task { @MainActor [weak self] in
      guard let self else { return }
      for await event in clerkEventEmitter.events {
        // Process synchronously since we're already on MainActor
        if case .deviceTokenReceived(let token) = event {
          // Save device token to keychain
          do {
            try self.dependencies.keychain.set(token, forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
          } catch {
            ClerkLogger.logError(error, message: "Failed to save device token to keychain")
          }

          // Sync to watch app if enabled
          self.watchConnectivityCoordinator?.sync()
        }

        if case .clientReceived(let client) = event {
          // Update client from event
          self.client = client
        }

        if case .environmentReceived(let environment) = event {
          // Update environment from event
          self.environment = environment
        }
      }
    }
  }

  /// Cleans up managers that were started during configuration.
  /// Used during testing to ensure old managers are properly cleaned up before reconfiguration.
  package func cleanupManagers() {
    sessionPollingManager?.stopPolling()
    sessionPollingManager = nil
    lifecycleManager?.stopObserving()
    lifecycleManager = nil
    authEventListenerTask?.cancel()
    authEventListenerTask = nil
    clerkEventListenerTask?.cancel()
    clerkEventListenerTask = nil
    watchConnectivityCoordinator?.stop()
    watchConnectivityCoordinator = nil
  }
}
