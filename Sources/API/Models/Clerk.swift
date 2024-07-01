//
//  Clerk.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import Factory
import RegexBuilder
import Nuke
import Get
import SimpleKeychain

#if canImport(UIKit)
import UIKit
#endif

/**
 This is the main entrypoint class for the clerk package. It contains a number of methods and properties for interacting with the Clerk API.
 */
final public class Clerk: ObservableObject {
    
    // MARK: - Dependencies
    
    public static var shared: Clerk {
        // singleton scope
        Container.shared.clerk()
    }
    
    var apiClient: APIClient {
        // cache scope
        Container.shared.apiClient()
    }
    
    // MARK: - Setup Functions
                
    /// Configures the shared clerk instance.
    /// - Parameter publishableKey: The publishable key from your Clerk Dashboard, used to connect to Clerk.
    public func configure(publishableKey: String) {
        if publishableKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            dump("Clerk configured without a publishable key. Please include a valid publishable key.")
            return
        }
        
        self.publishableKey = publishableKey
        Container.shared.reset()
    }
    
    /// Loads all necessary environment configuration and instance settings from the Frontend API.
    /// It is absolutely necessary to call this method before using the Clerk object in your code.
    @MainActor
    public func load() async throws {
        if publishableKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            dump("Clerk loaded without a publishable key. Please call configure() with a valid publishable key first.")
            loadingState = .failed
            return
        }
        
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { [self] in
                    try await getOrCreateClient()
                    startSessionTokenPolling()
                }
                
                group.addTask { [self] in
                    try await getEnvironment()
                    prefetchImages()
                }
                
                while let _ = try await group.next() {}
            }
            
            #if canImport(UIKit)
            didBecomeActiveObserver = NotificationCenter.default.addObserver(
                self,
                selector: #selector(startSessionTokenPolling),
                name: UIApplication.didBecomeActiveNotification,
                object: nil
            )
            
            didEnterBackgroundObserver = NotificationCenter.default.addObserver(
                self,
                selector: #selector(stopSessionTokenPolling),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
            #endif
            
            loadingState = .loadedFromNetwork
            
        } catch {
            loadingState = .failed
            throw error
        }
        
    }
    
    // MARK: - Public Properties
    
    public enum LoadingState {
        case notLoaded
        case loadedFromNetwork
        case failed
    }
    
    /// The loading state of the Clerk object.
    @Published private(set) public var loadingState: LoadingState = .notLoaded
    
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
    private(set) public var frontendAPIURL: String = ""
    
    /// The currently active Session, which is guaranteed to be one of the sessions in Client.sessions. If there is no active session, this field will be null.
    public var session: Session? {
        client?.lastActiveSession
    }
    
    /// A shortcut to Session.user which holds the currently active User object. If the session is null or undefined, the user field will match.
    public var user: User? {
        client?.lastActiveSession?.user
    }
    
    /// The Client object for the current device.
    @Published internal(set) public var client: Client? {
        didSet {
            if let lastActiveSessionId = client?.lastActiveSessionId {
                try? SimpleKeychain().set(lastActiveSessionId, forKey: "lastActiveSessionId")
            } else {
                try? SimpleKeychain().deleteItem(forKey: "lastActiveSessionId")
            }
        }
    }
        
    /// The Environment for the clerk instance.
    @Published internal(set) public var environment: Clerk.Environment?
    
    /// The retrieved active sessions for this user.
    ///
    /// Is set by the `getSessions` function on a user.
    @Published var sessionsByUserId: [String: [Session]] = .init()
    
    /// The configurable redirect settings. For example: `redirectUrl`, `callbackUrlScheme`
    public var redirectConfig = RedirectConfig()
    
    // MARK: - Internal Properties
    
    /// The cached session tokens. Key is the session id + template name if there is one.
    /// e.g. `sess_abc12345` or `sess_abc12345-supabase`
    ///
    /// Is set by the `getToken` function on a session.
    var sessionTokensByCacheKey: [String: TokenResource] = .init()
    
    // MARK: - Private Setup
        
    private var didBecomeActiveObserver: Void?
    private var didEnterBackgroundObserver: Void?
    private var sessionPollingTask: Task<Void, Error>?
        
    @objc
    private func startSessionTokenPolling() {
        guard sessionPollingTask == nil || sessionPollingTask?.isCancelled == true else {
            return
        }
        
        sessionPollingTask = Task(priority: .background) {
            repeat {
                if let session {
                    _ = try? await session.getToken(.init(skipCache: true))
                }
                try await Task.sleep(for: .seconds(50))
            } while sessionPollingTask?.isCancelled == false
        }
    }
    
    @objc
    private func stopSessionTokenPolling() {
        sessionPollingTask?.cancel()
        sessionPollingTask = nil
    }
    
    private let imagePrefetcher = ImagePrefetcher(pipeline: .shared, destination: .diskCache)
    
    private func prefetchImages() {
        guard let environment else { return }
        
        var imageUrls: [URL?] = []
        
        if let logoUrl = URL(string: environment.displayConfig.logoImageUrl) {
            imageUrls.append(logoUrl)
        }
        
        environment.userSettings.enabledThirdPartyProviders.forEach { provider in
            imageUrls.append(provider.iconImageUrl())
            if provider.hasDarkModeVariant {
                imageUrls.append(provider.iconImageUrl(darkMode: true))
            }
        }
        
        imagePrefetcher.startPrefetching(with: imageUrls.compactMap { $0 })
    }
    
    deinit {
        stopSessionTokenPolling()
        didBecomeActiveObserver = nil
        didEnterBackgroundObserver = nil
    }
    
    /// Enable for additional debugging signals
    public var debugMode: Bool = false
}

// MARK: - Public Functions

extension Clerk {
    
    /**
     Signs out the active user from all sessions in a multi-session application, or simply the current session in a single-session context. The current client will be deleted. You can also specify a specific session to sign out by passing the sessionId parameter.
     - Parameter sessionId: Specify a specific session to sign out. Useful for multi-session applications.
     */
    @MainActor
    public func signOut(sessionId: String? = nil) async throws {
        if let sessionId {
            let request = ClerkAPI.v1.client.sessions.id(sessionId).remove.post
            try await Clerk.shared.apiClient.send(request)
            try await Client.get()
            if let client, client.sessions.isEmpty {
                try await client.destroy()
                try await Client.create()
            }
        } else {
            try await client?.destroy()
            try await Client.create()
        }
    }
    
    /// A method used to set the active session and/or organization.
    /// - Parameter sessionId: The session ID to be set as active. If null, the current session is deleted.
    /// - Parameter organizationId: The organization ID to be set as active in the current session. If null, the currently active organization is removed as active.
    @MainActor
    public func setActive(sessionId: String?, organizationId: String? = nil) async throws {
        if let sessionId = sessionId {
            let request = ClerkAPI.v1.client.sessions.id(sessionId).touch.post(organizationId: organizationId)
            try await Clerk.shared.apiClient.send(request)
            try await Client.get()
            
        } else if let currentSession = session {
            try await currentSession.revoke()
            try await Client.get()
        }
    }
    
    /// Creates a new client for the current instance along with its authorization header.
    @MainActor
    func createClient() async throws {
        try await Client.create()
    }
    
    /// Fetches the client from the server, if one doesn't exist for the device then create one.
    @MainActor
    func getOrCreateClient() async throws {
        let client = try await Client.get()
        if client == nil {
            try await Client.create()
        }
    }
    
    @MainActor
    public func getEnvironment() async throws {
        try await Environment.get()
    }
    
}
