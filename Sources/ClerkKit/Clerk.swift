//
//  Clerk.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import RegexBuilder

#if canImport(UIKit)
import UIKit
#endif

/**
 This is the main entrypoint class for the clerk package. It contains a number of methods and properties for interacting with the Clerk API.
 */
@Observable
final public class Clerk {

    /// The internal singleton instance backing `shared`.
    private static var clerk: Clerk?

    /// The configured shared instance of ``Clerk``.
    ///
    /// - Warning: You must call ``configure(publishableKey:options:)`` before accessing this.
    public static var shared: Clerk {
        guard let clerk = clerk else {
            assertionFailure("Clerk has not been configured. Please call Clerk.configure(publishableKey:options:)")
            return Clerk()
        }
        return clerk
    }

    /// Tracks whether ``Clerk.configure`` has been called.
    public private(set) static var isConfigured = false

    /// Configures a shared instance of ``Clerk`` for use throughout your app.
    ///
    /// Call this as soon as your app finishes launching, typically from ``UIApplicationDelegate`` or
    /// your SwiftUI app entry point. See our configuration guide in the documentation for details.
    ///
    /// - Parameters:
    ///   - publishableKey: The publishable key from your Clerk Dashboard. Must start with
    ///     `pk_live_` or `pk_test_`.
    ///   - options: ``ClerkOptions`` that customize logging, telemetry, and persistence behaviour.
    public static func configure(
        publishableKey: String,
        options: ClerkOptions = .init()
    ) {
        guard clerk == nil else {
            ClerkLogger.warning(
                "Clerk.configure called multiple times. Ignoring subsequent call.",
                debugMode: true
            )
            return
        }

        let container = DependencyContainer(options: options)
        let clerk = Clerk(dependencyContainer: container)
        clerk.publishableKey = publishableKey
        self.clerk = clerk
        isConfigured = true

        ClerkLogger.info(
            "Clerk SDK version \(Clerk.version). Instance type: \(clerk.instanceType)",
            debugMode: true
        )
    }

    /// Access the configured options that drive Clerk behaviour.
    public var options: ClerkOptions {
        dependencyContainer.options
    }

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
                try? saveClientToKeychain(client)
                logPendingSessionStatusIfNeeded(previousClient: oldValue, currentClient: client)
            } else {
                try? dependencyContainer.keychain.deleteItem(forKey: "cachedClient")
            }
        }
    }
    /// The telemetry collector for development diagnostics.
    ///
    /// Initialized with a default collector and refreshed during `load()`.
    /// Used to record non-blocking telemetry events when running in development
    @_spi(Internal)
    @ObservationIgnored
    public private(set) var telemetry: TelemetryCollector = TelemetryCollector()

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
    private(set) public var publishableKey: String = "" {
        didSet {
            let liveRegex = Regex {
                "pk_live_"
                Capture {
                    OneOrMore(.any)
                }
            }

            let testRegex = Regex {
                "pk_test_"
                Capture {
                    OneOrMore(.any)
                }
            }

            if let match = publishableKey.firstMatch(of: liveRegex)?.output.1 ?? publishableKey.firstMatch(of: testRegex)?.output.1,
                let apiUrl = String(match).base64String()
            {
                frontendApiUrl = "https://\(apiUrl.dropLast())"
            }
        }
    }

    /// The event emitter for auth events.
    public let authEventEmitter = EventEmitter<AuthEvent>()

    /// The Clerk environment for the instance.
    public var environment = Environment() {
        didSet {
            try? saveEnvironmentToKeychain(environment)
        }
    }

    // MARK: - Private Properties

    let dependencyContainer: DependencyContainer

    init(dependencyContainer: DependencyContainer = DependencyContainer()) {
        self.dependencyContainer = dependencyContainer
        loadCachedClient()
        loadCachedEnvironment()
    }

    /// Frontend API URL.
    private(set) var frontendApiUrl: String = "" {
        didSet {
            dependencyContainer.updateFrontendAPIURL(frontendApiUrl)
        }
    }

    /// Holds a reference to the task performed when the app will enter the foreground.
    private var willEnterForegroundTask: Task<Void, Error>?

    /// Holds a reference to the task performed when the app entered the background.
    private var didEnterBackgroundTask: Task<Void, Error>?

    /// Holds a reference to the session polling task.
    private var sessionPollingTask: Task<Void, Error>?

}

extension Clerk {

    /// Loads all necessary environment configuration and instance settings from the Frontend API.
    /// It is absolutely necessary to call this method before using the Clerk object in your code.
    @MainActor
    public func load() async throws {
        if publishableKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ClerkLogger.error("Clerk loaded without a publishable key. Please call configure() with a valid publishable key first.")
            return
        }

        do {
            startSessionTokenPolling()
            setupNotificationObservers()

            // Both of these are automatically applied to the shared instance:
            async let client = Client.get()  // via middleware
            async let environment = Environment.get()  // via the function itself

            _ = try await client
            attestDeviceIfNeeded(environment: try await environment)

            isLoaded = true

            // Refresh telemetry collector after successful load
            telemetry = TelemetryCollector()
        } catch {
            throw error
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
    @MainActor
    public func signOut(sessionId: String? = nil) async throws {
      if let sessionId {
        let request = Request<NoContent>.build(path: "/v1/client/sessions/\(sessionId)/remove") {
          $0.method(.post)
        }

        try await dependencyContainer.apiClient.send(request)
      } else {
        let request = Request<NoContent>.build(path: "/v1/client/sessions") {
          $0.method(.delete)
        }

        try await dependencyContainer.apiClient.send(request)
      }
    }

    /// A method used to set the active session.
    ///
    /// Useful for multi-session applications.
    ///
    /// - Parameter sessionId: The session ID to be set as active.
    /// - Parameter organizationId: The organization ID to be set as active in the current session. If nil, the currently active organization is removed as active.
    @MainActor
    public func setActive(sessionId: String, organizationId: String? = nil) async throws {
        let request = Request<NoContent>.build(path: "/v1/client/sessions/\(sessionId)/touch") {
            $0.method(.post)
            $0.body(["active_organization_id": organizationId ?? ""])
        }

        try await dependencyContainer.apiClient.send(request)
    }

    // MARK: - Testing Utilities

    /// Overrides the networking client used by Clerk. Intended for tests.
    @MainActor
    @_spi(Internal)
    public func use(apiClient: MockAPIClient) {
        dependencyContainer.overrideApiClient(apiClient)
    }

    /// Restores the default networking client constructed from the configured frontend API URL.
    @_spi(Internal)
    public func resetAPIClientToDefault() {
        let baseURL = frontendApiUrl.isEmpty ? nil : URL(string: frontendApiUrl)
        dependencyContainer.resetApiClient(baseURL: baseURL)
    }
}

extension Clerk {

    private func logPendingSessionStatusIfNeeded(previousClient: Client?, currentClient: Client) {
        guard shouldLogPendingSessionStatus(previousClient: previousClient, currentClient: currentClient) else { return }

        let tasksDescription: String
        if let sessionId = currentClient.lastActiveSessionId,
           let session = currentClient.sessions.first(where: { $0.id == sessionId }),
           let tasks = session.tasks,
           !tasks.isEmpty
        {
            let taskKeys = tasks.map(\.key).joined(separator: ", ")
            tasksDescription = " Remaining session tasks: [\(taskKeys)]."
        } else {
            tasksDescription = ""
        }

        let message = "Your session is currently pending. Complete the remaining session tasks to activate it.\(tasksDescription)"
        ClerkLogger.info(message, debugMode: true)
    }

    func shouldLogPendingSessionStatus(previousClient: Client?, currentClient: Client) -> Bool {
        guard let sessionId = currentClient.lastActiveSessionId,
              let session = currentClient.sessions.first(where: { $0.id == sessionId })
        else {
            return false
        }

        guard session.status == .pending else { return false }

        guard let previousClient,
              let previousId = previousClient.lastActiveSessionId,
              let previousSession = previousClient.sessions.first(where: { $0.id == previousId })
        else {
            return true
        }

        if previousSession.id != session.id { return true }
        if previousSession.status != session.status { return true }
        if (previousSession.tasks ?? []) != (session.tasks ?? []) { return true }

        return false
    }

    private func setupNotificationObservers() {
        #if !os(watchOS) && !os(macOS)

        // cancel existing tasks if they exist (switching instances)
        willEnterForegroundTask?.cancel()
        didEnterBackgroundTask?.cancel()

        willEnterForegroundTask = Task {
            for await _ in NotificationCenter.default.notifications(
                named: UIApplication.willEnterForegroundNotification
            ).map({ _ in () }) {
                self.startSessionTokenPolling()

                // Start both functions concurrently without waiting for them
                Task { @MainActor in
                    try? await Client.get()
                }

                Task { @MainActor in
                    try? await Environment.get()
                }
            }
        }

        didEnterBackgroundTask = Task { @MainActor in
            for await _ in NotificationCenter.default.notifications(
                named: UIApplication.didEnterBackgroundNotification
            ).map({ _ in () }) {
                stopSessionTokenPolling()
                
                Task {
                    await telemetry.flush()
                }
            }
        }

        #endif
    }

    private func startSessionTokenPolling() {
        guard sessionPollingTask == nil || sessionPollingTask?.isCancelled == true else {
            return
        }

        sessionPollingTask = Task(priority: .background) { @MainActor in
            repeat {
                if let session = session {
                    _ = try? await session.getToken()
                }
                try await Task.sleep(for: .seconds(5), tolerance: .seconds(0.1))
            } while !Task.isCancelled
        }
    }

    private func stopSessionTokenPolling() {
        sessionPollingTask?.cancel()
        sessionPollingTask = nil
    }

    private func attestDeviceIfNeeded(environment: Environment) {
        if !AppAttestHelper.hasKeyId, [.onboarding, .enforced].contains(environment.fraudSettings?.native.deviceAttestationMode) {
            Task {
                do {
                    try await AppAttestHelper.performDeviceAttestation()
                } catch {
                    ClerkLogger.logError(error, message: "Device attestation failed")
                }
            }
        }
    }

    private func loadCachedClient() {
        do {
            if let cachedClient = try loadClientFromKeychain() {
                // Only set cached client if we don't already have one
                // This prevents overwriting fresh data during load()
                if self.client == nil {
                    self.client = cachedClient
                }
            }
        } catch {
            ClerkLogger.logError(error, message: "Failed to load cached client")
        }
    }

    private func loadCachedEnvironment() {
        do {
            if let cachedEnvironment = try loadEnvironmentFromKeychain() {
                // Only set cached environment if we don't already have fresh data
                // This prevents overwriting fresh data during load()
                if self.environment.isEmpty {
                    self.environment = cachedEnvironment
                }
            }
        } catch {
            ClerkLogger.logError(error, message: "Failed to load cached environment")
        }
    }

    private func saveClientToKeychain(_ client: Client) throws {
        let clientData = try JSONEncoder.clerkEncoder.encode(client)
        try dependencyContainer.keychain.set(clientData, forKey: "cachedClient")
    }

    private func loadClientFromKeychain() throws -> Client? {
        guard let clientData = try? dependencyContainer.keychain.data(forKey: "cachedClient") else {
            return nil
        }
        let decoder = JSONDecoder.clerkDecoder
        return try decoder.decode(Client.self, from: clientData)
    }

    private func saveEnvironmentToKeychain(_ environment: Clerk.Environment) throws {
        let encoder = JSONEncoder.clerkEncoder
        let environmentData = try encoder.encode(environment)
        try dependencyContainer.keychain.set(environmentData, forKey: "cachedEnvironment")
    }

    private func loadEnvironmentFromKeychain() throws -> Clerk.Environment? {
        guard let environmentData = try? dependencyContainer.keychain.data(forKey: "cachedEnvironment") else {
            return nil
        }
        let decoder = JSONDecoder.clerkDecoder
        return try decoder.decode(Clerk.Environment.self, from: environmentData)
    }

}

extension Clerk {

    @_spi(Internal)
    public static var mock: Clerk {
        let clerk = Clerk()
        clerk.client = .mock
        clerk.environment = .mock
        clerk.sessionsByUserId = [User.mock.id: [.mock, .mock2]]
        return clerk
    }

    @_spi(Internal)
    public static var mockSignedOut: Clerk {
        let clerk = Clerk()
        clerk.client = .mockSignedOut
        clerk.environment = .mock
        clerk.sessionsByUserId = [:]
        return clerk
    }

}

#if canImport(SwiftUI)
import SwiftUI

extension EnvironmentValues {
    @Entry public var clerk = Clerk.shared
}
#endif

extension Clerk {

    @_spi(Testing)
    public func configureForTesting(
        publishableKey: String,
        options: ClerkOptions = .init()
    ) {
        self.publishableKey = publishableKey
        dependencyContainer.updateOptions(options)
    }
}
