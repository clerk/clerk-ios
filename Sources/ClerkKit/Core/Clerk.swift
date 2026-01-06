//
//  Clerk.swift
//
//
//  Created by Mike Pitre on 10/2/23.
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
        auth.eventEmitter.send(.sessionChanged(session: SessionUtils.activeSession(from: client)))
      }

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
    client?.activeSession
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
  public var options: Clerk.ClerkOptions {
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
  package var watchConnectivityCoordinator: WatchConnectivityCoordinator?

  /// Task that listens for general Clerk events and handles them.
  private var clerkEventListenerTask: Task<Void, Never>?

  /// Dependency container holding all SDK dependencies.
  var dependencies: any Dependencies

  /// Backing storage for the `auth` property.
  ///
  /// This uses lazy initialization rather than a pure computed property because `Auth` contains
  /// an `EventEmitter` that must maintain stable identity across accesses. If `Auth` were recreated
  /// on every access, subscribers to `auth.events` would lose their subscriptions.
  ///
  /// Can be reset to `nil` to force reinitialization with new services after reconfiguration.
  @ObservationIgnored
  package var _auth: Auth?

  /// The main entry point for all authentication operations.
  ///
  /// Use this property to perform sign in, sign up, and session management operations.
  public var auth: Auth {
    if _auth == nil {
      _auth = Auth(
        signInService: dependencies.signInService,
        signUpService: dependencies.signUpService,
        sessionService: dependencies.sessionService
      )
    }
    return _auth!
  }

  /// The event emitter for general Clerk events.
  let clerkEventEmitter = EventEmitter<ClerkEvent>()

  /// An `AsyncStream` of general Clerk events.
  ///
  /// Subscribe to this stream to receive notifications about device tokens, client updates, and environment changes.
  var events: AsyncStream<ClerkEvent> {
    clerkEventEmitter.events
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
      dependencies = try! DependencyContainer(publishableKey: "", options: .init())
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
    startClerkEventListener()

    // Set up watch connectivity coordinator only if enabled
    if options.watchConnectivityEnabled {
      watchConnectivityCoordinator = WatchConnectivityCoordinator()
      watchConnectivityCoordinator?.start()
    }

    // Set up cache manager and load cached data synchronously
    let cacheManager = CacheManager(coordinator: self, keychain: dependencies.keychain)
    self.cacheManager = cacheManager
    cacheManager.loadCachedData()

    // Fire and forget: fetch fresh client and environment from API
    taskCoordinator?.task { @MainActor [weak self] in
      do {
        guard let self else { return }
        async let client = refreshClient()
        async let environment = refreshEnvironment()

        let env = try await environment
        _ = try await client
        attestDeviceIfNeeded(environment: env)
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
  static func configure(
    publishableKey: String,
    options: Clerk.ClerkOptions = .init()
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
  func refreshClient() async throws -> Client? {
    try await dependencies.clientService.get()
  }

  /// Refreshes the current environment from the API.
  func refreshEnvironment() async throws -> Environment {
    try await dependencies.environmentService.get()
  }
}

extension Clerk: CacheCoordinator {
  func setClientIfNeeded(_ client: Client?) {
    guard self.client == nil else { return }
    self.client = client
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
  private func attestDeviceIfNeeded(environment: Environment) {
    if !AppAttestHelper.hasKeyId,
       [.onboarding, .enforced].contains(environment.fraudSettings.native.deviceAttestationMode)
    {
      Task(priority: .background) {
        do {
          try await AppAttestHelper.performDeviceAttestation()
        } catch {
          ClerkLogger.logError(error, message: "Device attestation failed")
        }
      }
    }
  }

  /// Starts listening for general Clerk events and handles them.
  private func startClerkEventListener() {
    clerkEventListenerTask = Task { @MainActor [weak self] in
      guard let self else { return }
      for await event in clerkEventEmitter.events {
        switch event {
        case .deviceTokenReceived(let token):
          do {
            try dependencies.keychain.set(token, forKey: ClerkKeychainKey.clerkDeviceToken.rawValue)
          } catch {
            ClerkLogger.logError(error, message: "Failed to save device token to keychain")
          }

          watchConnectivityCoordinator?.sync()

        case .clientReceived(let client):
          self.client = client

        case .environmentReceived(let environment):
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
    clerkEventListenerTask?.cancel()
    clerkEventListenerTask = nil
    watchConnectivityCoordinator?.stop()
    watchConnectivityCoordinator = nil
    taskCoordinator?.cancelAll()
    taskCoordinator = nil
  }
}
