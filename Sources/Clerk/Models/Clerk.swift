//
//  Clerk.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import Factory
import RegexBuilder
import Get
import SimpleKeychain

#if canImport(UIKit)
import UIKit
#endif

/**
 This is the main entrypoint class for the clerk package. It contains a number of methods and properties for interacting with the Clerk API.
 */
@MainActor
@Observable
final public class Clerk {
    
    public static let shared: Clerk = Container.shared.clerk()
    
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
            if let lastActiveSessionId = client?.lastActiveSessionId {
                try? SimpleKeychain().set(lastActiveSessionId, forKey: "lastActiveSessionId")
            } else {
                try? SimpleKeychain().deleteItem(forKey: "lastActiveSessionId")
            }
        }
    }
    
    /// The currently active Session, which is guaranteed to be one of the sessions in Client.sessions. If there is no active session, this field will be nil.
    public var session: Session? {
        guard let client else { return nil }
        return client.sessions.first(where: { $0.id == client.lastActiveSessionId })
    }
    
    /// A shortcut to Session.user which holds the currently active User object. If the session is nil, the user field will match.
    public var user: User? {
        session?.user
    }
    
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
               let apiUrl = String(match).base64String() {
                frontendApiUrl = "https://\(apiUrl.dropLast())"
            }
        }
    }
    
    /// Frontend API URL
    private(set) public var frontendApiUrl: String = ""
    
    /// The retrieved active sessions for this user.
    ///
    /// Is set by the `getSessions` function on a user.
    internal(set) public var sessionsByUserId: [String: [Session]] = .init()
    
    /// The configurable redirect settings. For example: `redirectUrl`, `callbackUrlScheme`
    public var redirectConfig = RedirectConfig()
    
    /// The event emitter for auth events.
    public let authEventEmitter = EventEmitter<AuthEvent>()
    
    /// Enable for additional debugging signals
    private(set) public var debugMode: Bool = false
    
    /// The Clerk environment for the instance.
    var environment = Environment()
        
    // MARK: - Private Properties
    
    nonisolated init() {}
    
    /// The cached session tokens.
    ///
    /// Key is the session id + template name if there is one.
    /// - e.g. `sess_abc12345` or `sess_abc12345-supabase`
    ///
    /// - Is set by the `getToken` function on a session.
    var sessionTokensByCacheKey: [String: TokenResource] = .init()
                
    /// Holds a reference to the task performed when the app will enter the foreground.
    private var willEnterForegroundTask: Task<Void, Error>?
    
    /// Holds a reference to the task performed when the app entered the background.
    private var didEnterBackgroundTask: Task<Void, Error>?
    
    /// Holds a reference to the session polling task.
    private var sessionPollingTask: Task<Void, Error>?
}

extension Clerk {
    
    /// Configures the shared clerk instance.
    /// - Parameters:
    ///     - publishableKey: The publishable key from your Clerk Dashboard, used to connect to Clerk.
    ///     - debugMode: Enable for additional debugging signals.
    public func configure(publishableKey: String, debugMode: Bool = false) {
        if publishableKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            dump("Clerk configured without a publishable key. Please include a valid publishable key.")
            return
        }
        
        self.publishableKey = publishableKey
        self.debugMode = debugMode
    }
    
    /// Loads all necessary environment configuration and instance settings from the Frontend API.
    /// It is absolutely necessary to call this method before using the Clerk object in your code.
    public func load() async throws {
        if publishableKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            dump("Clerk loaded without a publishable key. Please call configure() with a valid publishable key first.")
            isLoaded = false
            return
        }
        
        do {
            async let client = Client.get()
            async let environment = Environment.get()
            _ = try await (client, environment)
            startSessionTokenPolling()
            setupNotificationObservers()
            isLoaded = true
        } catch {
            isLoaded = false
            throw error
        }
    }
    
    /**
     Signs out the active user from all sessions in a multi-session application, or simply the current session in a single-session context. You can also specify a specific session to sign out by passing the sessionId parameter.
     - Parameter sessionId: Specify a specific session to sign out. Useful for multi-session applications.
     */
    public func signOut(sessionId: String? = nil) async throws {
        if let sessionId {
            let request = ClerkFAPI.v1.client.sessions.id(sessionId).remove.post
            let response = try await Clerk.shared.apiClient.send(request)
            Clerk.shared.client = response.value.client
        } else {
            let request = ClerkFAPI.v1.client.sessions.delete
            let response = try await Clerk.shared.apiClient.send(request)
            Clerk.shared.client = response.value.client
        }
    }
    
    /// A method used to set the active session and/or organization.
    /// - Parameter sessionId: The session ID to be set as active.
    public func setActive(sessionId: String) async throws {
        let request = ClerkFAPI.v1.client.sessions.id(sessionId).touch.post
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
    }
}

extension Clerk {
    
    // MARK: - Private Properties
    
    var apiClient: APIClient {
        Container.shared.apiClient(frontendApiUrl)
    }
    
    private func setupNotificationObservers() {
        #if !os(watchOS) && !os(macOS)
        
        // cancel existing tasks if they exist (switching instances)
        willEnterForegroundTask?.cancel()
        didEnterBackgroundTask?.cancel()
        
        willEnterForegroundTask = Task {
            for await _ in NotificationCenter.default.notifications(named: UIApplication.willEnterForegroundNotification).map({ _ in () }) {
                self.startSessionTokenPolling()
                
                // Start both functions concurrently without waiting for them
                Task.detached {
                    _ = try? await Client.get()
                }
                
                Task.detached {
                    _ = try? await Environment.get()
                }
            }
        }
        
        didEnterBackgroundTask = Task {
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didEnterBackgroundNotification).map({ _ in () }) {
                stopSessionTokenPolling()
            }
        }
        
        #endif
    }

    private func startSessionTokenPolling() {
        guard sessionPollingTask == nil || sessionPollingTask?.isCancelled == true else {
            return
        }
        
        sessionPollingTask = Task(priority: .background) {
            repeat {
                if let session = session {
                    _ = try? await session.getToken(.init(skipCache: true))
                }
                try await Task.sleep(for: .seconds(50), tolerance: .seconds(0.1))
            } while !Task.isCancelled
        }
    }
    
    private func stopSessionTokenPolling() {
        sessionPollingTask?.cancel()
        sessionPollingTask = nil
    }
    
}

extension Container {
    var clerk: Factory<Clerk> {
        self { Clerk() }.singleton
    }
    
}
