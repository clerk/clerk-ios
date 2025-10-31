//
//  Clerk.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import FactoryKit
import Foundation

/**
 This is the main entrypoint class for the clerk package. It contains a number of methods and properties for interacting with the Clerk API.
 */
@MainActor
@Observable
final public class Clerk {

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
    internal static var _shared: Clerk?

    /// A getter to see if the Clerk object is ready for use or not.
    private(set) public var isLoaded: Bool = false

    /// A getter to see if a Clerk instance is running in production or development mode.
    public var instanceType: InstanceEnvironmentType {
        if publishableKey.starts(with: "pk_live_") {
            return .production
        }
        return .development
    }

    /// The Client object for the current device.
    internal(set) public var client: Client? {
        didSet {
            if let client = client {
                cacheManager?.saveClient(client)
                sessionStatusLogger.logPendingSessionStatusIfNeeded(previousClient: oldValue, currentClient: client)
            } else {
                cacheManager?.deleteClient()
            }
        }
    }
    /// The telemetry collector for development diagnostics.
    ///
    /// Initialized with a default collector and refreshed during `load()`.
    /// Used to record non-blocking telemetry events when running in development
    package private(set) var telemetry: TelemetryCollector = TelemetryCollector()

    /// Your Clerk app's proxy URL. Required for applications that run behind a reverse proxy. Must be a full URL (for example, https://proxy.example.com/__clerk).
    public private(set) var proxyUrl: URL? {
        get {
            configurationManager.proxyUrl
        }
        set {
            configurationManager.updateProxyUrl(newValue)
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
    internal(set) public var sessionsByUserId: [String: [Session]] = [:]
    
    /// The publishable key from your Clerk Dashboard, used to connect to Clerk.
    public var publishableKey: String {
        configurationManager.publishableKey
    }

    /// The event emitter for auth events.
    public let authEventEmitter = EventEmitter<AuthEvent>()
    
    /// The Clerk environment for the instance.
    public internal(set) var environment = Environment() {
        didSet {
            cacheManager?.saveEnvironment(environment)
        }
    }
    
    /// The configuration options for this Clerk instance.
    public var options: Clerk.ClerkOptions {
        configurationManager.options
    }

    // MARK: - Private Properties
    
    /// Coordinates task lifecycle and cleanup.
    private var taskCoordinator: TaskCoordinator?
    
    /// Task that coordinates cached data loading during initialization.
    /// This is set during `configure()` and awaited during `load()`.
    /// Stored as nonisolated to allow cancellation from deinit.
    nonisolated private var cachedDataLoadingTask: Task<Void, Never>?
    
    /// Frontend API URL.
    internal var frontendApiUrl: String {
        configurationManager.frontendApiUrl
    }

    /// Manages caching of client and environment data.
    private var cacheManager: CacheManager?
    
    /// Manages Clerk configuration including API client setup and options.
    private var configurationManager = ConfigurationManager()
    
    /// Manages app lifecycle notifications and coordinates foreground/background transitions.
    private var lifecycleManager: LifecycleManager?
    
    /// Manages periodic polling of session tokens to keep them refreshed.
    private var sessionPollingManager: SessionPollingManager?
    
    /// Manages logging of session status changes.
    private var sessionStatusLogger = SessionStatusLogger()

    /// Proxy configuration derived from `proxyUrl`, if present.
    internal var proxyConfiguration: ProxyConfiguration? {
        configurationManager.proxyConfiguration
    }
    
    /// Cancels all tracked tasks and cleans up resources.
    ///
    /// This ensures proper cleanup when the Clerk instance is deallocated.
    /// Managers handle their own cleanup in their deinit methods.
    deinit {
        // Cancel cached data loading task if still running
        cachedDataLoadingTask?.cancel()
        
        // Managers will clean up themselves when deallocated
        // taskCoordinator, lifecycleManager, and sessionPollingManager
        // all have deinit methods that handle cleanup
    }

}

extension Clerk {
    
    /// Validates the publishable key format and throws an error if invalid.
    ///
    /// - Parameter key: The publishable key to validate.
    /// - Throws: `ClerkInitializationError` if the key is empty or has an invalid format.
    private func validatePublishableKey(_ key: String) throws {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedKey.isEmpty else {
            throw ClerkInitializationError.missingPublishableKey
        }
        
        guard trimmedKey.starts(with: "pk_test_") || trimmedKey.starts(with: "pk_live_") else {
            throw ClerkInitializationError.invalidPublishableKeyFormat(key: trimmedKey)
        }
    }
    
    /// Internal helper method that performs the actual configuration work.
    /// This is shared between `configure()` and `_reconfigure()`.
    @MainActor
    private func performConfiguration(publishableKey: String, options: Clerk.ClerkOptions) throws {
        // Validate publishable key early for fail-fast behavior
        try validatePublishableKey(publishableKey)
        
        // Initialize task coordinator
        taskCoordinator = TaskCoordinator()
        
        // Configure using ConfigurationManager
        try configurationManager.configure(publishableKey: publishableKey, options: options)
        
        // Set up cache manager and load cached data asynchronously
        let cacheManager = CacheManager(coordinator: self)
        self.cacheManager = cacheManager
        
        // Load cached data asynchronously (don't block on this)
        cachedDataLoadingTask = Task { @MainActor in
            await cacheManager.loadCachedData()
        }
    }

    /// Configures the shared Clerk instance.
    /// 
    /// This method must be called before accessing `Clerk.shared`. It can only be called once.
    /// 
    /// This method:
    /// 1. Sets up configuration (API client, options, etc.)
    /// 2. Starts loading cached client and environment data from keychain (asynchronously)
    /// 3. Sets the shared instance
    /// 
    /// - Parameters:
    ///     - publishableKey: The publishable key from your Clerk Dashboard, used to connect to Clerk.
    ///     - options: Configuration options for the Clerk instance. Defaults to a new `ClerkOptions` instance.
    @MainActor
    public static func configure(
        publishableKey: String,
        options: Clerk.ClerkOptions = .init()
    ) {
        precondition(_shared == nil, "Clerk has already been configured. Configure can only be called once.")
        
        let clerk = Clerk()
        
        do {
            try clerk.performConfiguration(publishableKey: publishableKey, options: options)
        } catch {
            preconditionFailure("Failed to configure Clerk: \(error.localizedDescription)")
        }
        
        _shared = clerk
    }
    
    /// Internal method for reconfiguring Clerk instance (for debugging purposes).
    /// 
    /// This allows reconfiguration of the Clerk instance during debugging.
    /// 
    /// This method:
    /// 1. Sets up configuration (API client, options, etc.)
    /// 2. Starts loading cached client and environment data from keychain (asynchronously)
    /// 3. Sets the shared instance
    /// 
    /// - Parameters:
    ///     - publishableKey: The publishable key from your Clerk Dashboard, used to connect to Clerk.
    ///     - options: Configuration options for the Clerk instance. Defaults to a new `ClerkOptions` instance.
    @MainActor
    package static func _reconfigure(
        publishableKey: String,
        options: Clerk.ClerkOptions = .init()
    ) {
        let clerk = Clerk()
        
        do {
            try clerk.performConfiguration(publishableKey: publishableKey, options: options)
        } catch {
            preconditionFailure("Failed to reconfigure Clerk: \(error.localizedDescription)")
        }
        
        _shared = clerk
    }

    /// Loads all necessary environment configuration and instance settings from the Frontend API.
    /// It is absolutely necessary to call this method before using the Clerk object in your code.
    ///
    /// - Throws: `ClerkInitializationError` if initialization fails, or errors from network operations.
    ///
    /// - Note: This method validates the publishable key format and throws an error if it's invalid.
    ///   Keychain errors are logged but do not prevent initialization from proceeding.
    ///   This method waits for cached data loading to complete before loading fresh data.
    public func load() async throws {
        // Ensure cached data loading has completed
        await cachedDataLoadingTask?.value
        
        // Ensure Clerk has been configured
        guard cachedDataLoadingTask != nil else {
            throw ClerkInitializationError.initializationFailed(
                underlyingError: NSError(
                    domain: "ClerkError",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Clerk must be configured before calling load(). Call Clerk.configure() first."]
                )
            )
        }
        
        // Validate publishable key (should already be validated in configure, but double-check)
        try validatePublishableKey(publishableKey)
        
        do {
            // Set up session polling manager
            sessionPollingManager = SessionPollingManager(getSession: { [weak self] in self?.session })
            sessionPollingManager?.startPolling()
            
            // Set up lifecycle manager for foreground/background transitions
            lifecycleManager = LifecycleManager(handler: self)
            lifecycleManager?.startObserving()

            // Fetch client and environment concurrently
            // Both of these are automatically applied to the shared instance:
            async let client = Client.get()  // via middleware
            async let environment = Environment.get()  // via the function itself
            
            // Wait for both to complete - if either fails, we exit early
            // since both are required for the SDK to work properly
            do {
                let env = try await environment
                _ = try await client
                attestDeviceIfNeeded(environment: env)
            } catch {
                // If client fails, environment will be cancelled automatically
                // If environment fails, we catch it here
                // Wrap in appropriate error type
                throw ClerkInitializationError.initializationFailed(underlyingError: error)
            }

            isLoaded = true

            // Refresh telemetry collector after successful load
            telemetry = TelemetryCollector()
        } catch {
            cleanupManagers()
            
            // Wrap errors in appropriate ClerkInitializationError
            if let error = error as? ClerkInitializationError {
                throw error
            } else {
                // Try to determine which operation failed by checking error context
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
    public func signOut(sessionId: String? = nil) async throws {
        try await Container.shared.clerkService().signOut(sessionId: sessionId)
    }

    /// A method used to set the active session.
    ///
    /// Useful for multi-session applications.
    ///
    /// - Parameter sessionId: The session ID to be set as active.
    /// - Parameter organizationId: The organization ID to be set as active in the current session. If nil, the currently active organization is removed as active.
    public func setActive(sessionId: String, organizationId: String? = nil) async throws {
        try await Container.shared.clerkService().setActive(sessionId: sessionId, organizationId: organizationId)
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

extension Clerk: LifecycleEventHandling {
    
    /// Handles the app entering the foreground by resuming session polling and refreshing data.
    func onWillEnterForeground() async {
        sessionPollingManager?.startPolling()

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
    
    /// Cleans up managers that were started during load() if initialization fails.
    private func cleanupManagers() {
        sessionPollingManager?.stopPolling()
        lifecycleManager?.stopObserving()
        sessionPollingManager = nil
        lifecycleManager = nil
    }
}

extension Container {

    @MainActor
    var clerk: Factory<Clerk> {
        self { @MainActor in
            Clerk._shared ?? Clerk()
        }
        .singleton
    }

}

extension Clerk {

    package static var mock: Clerk {
        let clerk = Clerk()
        clerk.client = .mock
        clerk.environment = .mock
        clerk.sessionsByUserId = [User.mock.id: [.mock, .mock2]]
        return clerk
    }

    package static var mockSignedOut: Clerk {
        let clerk = Clerk()
        clerk.client = .mockSignedOut
        clerk.environment = .mock
        clerk.sessionsByUserId = [:]
        return clerk
    }

}
