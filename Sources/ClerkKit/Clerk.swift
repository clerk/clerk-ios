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
@Observable
final public class Clerk {

    /// The internal singleton instance backing `shared`.
    private static var clerk: Clerk?

    /// A variable that is only `true` if ``shared`` is available for use.
    /// Gets set to `true` immediately after
    /// ``configure(publishableKey:options:)`` is called.
    public private(set) static var isInitialized = false

    /// The configured shared instance of ``Clerk``.
    ///
    /// - Warning: You must call ``configure(publishableKey:options:)`` before accessing this.
    public static var shared: Clerk {
        guard let clerk else {
            Logger.log(
                level: .warning,
                message: "Clerk has not been configured. Please call Clerk.configure(publishableKey:options:)"
            )
            assertionFailure("Clerk has not been configured. Please call Clerk.configure(publishableKey:options:)")
            return Clerk()
        }
        return clerk
    }

    /// Configures a shared instance of ``Clerk`` for use throughout your app.
    ///
    /// Call this as soon as your app finishes launching, typically from ``UIApplicationDelegate`` or
    /// your SwiftUI app entry point. See our configuration guide in the documentation for details.
    ///
    /// - Parameters:
    ///   - publishableKey: The publishable key from your Clerk Dashboard. Must start with
    ///     `pk_live_` or `pk_test_`.
    ///   - options: ``ClerkOptions`` that customize logging, telemetry, and persistence behaviour.
    @discardableResult
    public static func configure(
        publishableKey: String,
        options: ClerkOptions? = nil
    ) -> Clerk {
        precondition(
            !publishableKey.isEmptyTrimmed,
            "Clerk.configure(publishableKey:options:) requires a non-empty publishable key."
        )

        guard clerk == nil else {
            Logger.log(
                level: .warning,
                message: "Clerk.configure called multiple times. Please make sure you only call this once on app launch."
            )
            return shared
        }

        clerk = Clerk(
            publishableKey: publishableKey,
            options: options
        )

        Logger.log(
            level: .debug,
            message: "Clerk SDK Version - \(Clerk.version)"
        )

        isInitialized = true

        return shared
    }

    /// Access the configured options that drive Clerk behaviour.
    public var options: ClerkOptions {
        dependencyContainer.configManager.options
    }

    /// Specifies the detail of the logs returned from the SDK to the console.
    public var logLevel: ClerkLogLevel {
        get { options.logging.level }
        set { options.logging.level = newValue }
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

    /// The publishable key from your Clerk Dashboard, used to connect to Clerk.
    public var publishableKey: String {
        dependencyContainer.configManager.publishableKey
    }

    /// Frontend API URL as a string.
    public var frontendApiUrl: String {
        dependencyContainer.configManager.frontendAPIURL?.absoluteString ?? ""
    }

    /// The Client object for the current device.
    internal(set) public var client: Client? {
        didSet {
            if let client {
                dependencyContainer.persistedStateStore.store(client: client)
                dependencyContainer.pendingSessionLogger.logChange(previousClient: oldValue, currentClient: client)
            } else {
                dependencyContainer.persistedStateStore.clearClient()
            }
        }
    }
    /// The telemetry collector for development diagnostics.
    @_spi(Internal)
    @ObservationIgnored
    public var telemetry: TelemetryCollector {
        dependencyContainer.telemetry
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

    /// The event emitter for auth events.
    public var authEventEmitter: EventEmitter<AuthEvent> {
        dependencyContainer.authEventEmitter
    }

    /// The Clerk environment for the instance.
    public var environment = Environment() {
        didSet {
            dependencyContainer.persistedStateStore.store(environment: environment)
        }
    }

    // MARK: - Private Properties

    let dependencyContainer: DependencyContainer

    init(dependencyContainer: DependencyContainer = DependencyContainer()) {
        self.dependencyContainer = dependencyContainer

        if self.client == nil,
           let cachedClient = dependencyContainer.persistedStateStore.restoreClient() {
            self.client = cachedClient
        }

        if environment.isEmpty,
           let cachedEnvironment = dependencyContainer.persistedStateStore.restoreEnvironment() {
            self.environment = cachedEnvironment
        }
    }

    private convenience init(
        publishableKey: String,
        options: ClerkOptions?
    ) {
        let dependencyContainer = DependencyContainer(options: options)
        dependencyContainer.configure(publishableKey: publishableKey)
        self.init(dependencyContainer: dependencyContainer)
    }

}

extension Clerk {

    /// Loads all necessary environment configuration and instance settings from the Frontend API.
    /// It is absolutely necessary to call this method before using the Clerk object in your code.
    @MainActor
    public func load() async throws {
        if publishableKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Logger.log(
                level: .warning,
                message: "Clerk loaded without a publishable key. Please call configure() with a valid publishable key first."
            )
            return
        }

        do {
            async let client = Client.get()
            async let environment = Environment.get()
            let (_, fetchedEnvironment) = try await (client, environment)
            dependencyContainer.deviceAttestationCoordinator.attestIfNeeded(with: fetchedEnvironment)

            isLoaded = true
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
}


extension Clerk {

    @_spi(Internal)
    public static var mock: Clerk {
        let clerk = Clerk(dependencyContainer: DependencyContainer())
        clerk.client = .mock
        clerk.environment = .mock
        clerk.sessionsByUserId = [User.mock.id: [.mock, .mock2]]
        return clerk
    }

    @_spi(Internal)
    public static var mockSignedOut: Clerk {
        let clerk = Clerk(dependencyContainer: DependencyContainer())
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
