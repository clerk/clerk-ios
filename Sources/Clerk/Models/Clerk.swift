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
@Observable
@MainActor
final public class Clerk {
    
    nonisolated init() {}
    
    // MARK: - Dependencies
    
    public static let shared: Clerk = Container.shared.clerk()
    
    var apiClient: APIClient {
        Container.shared.apiClient(frontendAPIURL)
    }
        
    // MARK: - Setup Functions
                
    /// Configures the shared clerk instance.
    /// - Parameter publishableKey: The publishable key from your Clerk Dashboard, used to connect to Clerk.
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
            loadingState = .failed
            return
        }
        
        do {
            try await Client.getOrCreate()
            let environment = try await Environment.get()
            
//            prefetchImages(environment: environment)
            startSessionTokenPolling()
            setupNotificationObservers()
            
            loadingState = .loaded
            
        } catch {
            loadingState = .failed
            throw error
        }
        
    }
    
    // MARK: - Public Properties
    
    public enum LoadingState {
        case notLoaded
        case loaded
        case failed
    }
    
    /// The loading state of the Clerk object.
    private(set) public var loadingState: LoadingState = .notLoaded
    
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
                frontendAPIURL = "https://\(apiUrl.dropLast())"
            }
        }
    }
    
    /// Frontend API URL
    public var frontendAPIURL: String = ""
    
    /// The currently active Session, which is guaranteed to be one of the sessions in Client.sessions. If there is no active session, this field will be null.
    public var session: Session? {
        client?.lastActiveSession
    }
    
    /// A shortcut to Session.user which holds the currently active User object. If the session is null or undefined, the user field will match.
    public var user: User? {
        client?.lastActiveSession?.user
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
        
    /// The Environment for the clerk instance.
    internal(set) public var environment: Clerk.Environment?
    
    /// The retrieved active sessions for this user.
    ///
    /// Is set by the `getSessions` function on a user.
    public var sessionsByUserId: [String: [Session]] = .init()
    
    /// The configurable redirect settings. For example: `redirectUrl`, `callbackUrlScheme`
    public var redirectConfig = RedirectConfig()
    
    // MARK: - Internal Properties
    
    /// The cached session tokens. Key is the session id + template name if there is one.
    /// e.g. `sess_abc12345` or `sess_abc12345-supabase`
    ///
    /// Is set by the `getToken` function on a session.
    var sessionTokensByCacheKey: [String: TokenResource] = .init()
    
    // MARK: - Private Setup
            
    private var willEnterForegroundTask: Task<Void, Error>?
    private var didEnterBackgroundTask: Task<Void, Error>?
    private var sessionPollingTask: Task<Void, Error>?
    
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
                    _ = try? await Client.getOrCreate()
                }
                
                Task.detached {
                    _ = try? await Clerk.Environment.get()
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
                if let session = Clerk.shared.session {
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
    
//    private func prefetchImages(environment: Clerk.Environment) {
//        var imageUrls: [URL?] = []
//        
//        if let logoUrl = URL(string: environment.displayConfig.logoImageUrl) {
//            imageUrls.append(logoUrl)
//        }
//        
//        environment.userSettings.authenticatableSocialProviders.forEach { provider in
//            imageUrls.append(provider.iconImageUrl())
//            if provider.hasDarkModeVariant {
//                imageUrls.append(provider.iconImageUrl(darkMode: true))
//            }
//        }
//        
//        let prefetcher = ImagePrefetcher(urls: imageUrls.compactMap { $0 })
//        prefetcher.start()
//    }
    
    /// Enable for additional debugging signals
    public var debugMode: Bool = false
}

// MARK: - Public Functions

extension Clerk {
    
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

extension Container {
    
    var clerk: Factory<Clerk> {
        self { Clerk() }.singleton
    }
    
}
