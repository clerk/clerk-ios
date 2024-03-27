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
import KeychainAccess

/**
 This is the main entrypoint class for the clerk package. It contains a number of methods and properties for interacting with the Clerk API.
 */
final public class Clerk: ObservableObject, @unchecked Sendable {
    
    public static var shared: Clerk {
        // singleton scope
        Container.shared.clerk()
    }
    
    var apiClient: APIClient {
        // cache scope
        Container.shared.apiClient()
    }
    
    var keychain: Keychain {
        // cache scope
        Container.shared.keychain()
    }
            
    init() {}
    
    /// Configure an instance of the Clerk class with dedicated options.
    /// - Parameter publishableKey: The publishable key from your Clerk Dashboard, used to connect to Clerk.
    ///
    /// Initializes the Clerk object and loads all necessary environment configuration and instance settings from the Frontend API.
    /// It is absolutely necessary to call this method before using the Clerk object in your code.
    @MainActor
    public func load(publishableKey: String) {
        if publishableKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            dump("Clerk loaded without a publishable key. Please include a valid publishable key.")
            return
        }
        
        self.publishableKey = publishableKey
        Container.shared.reset()
        
        Task.detached { [self] in
            await loadPersistedData()
            if !client.isNew {
                try await client.get()
            } else {
                try await client.create()
            }
            
            startSessionTokenPolling()
        }
        
        Task.detached { [self] in
            try await environment.get()
            prefetchImages()
        }
        
    }
    
    /// The publishable key from your Clerk Dashboard, used to connect to Clerk.
    private(set) public var publishableKey: String = "" {
        willSet {
            // If we're setting a new publishable key after an existing one, 
            // clear out the existing & persisted data
            if !publishableKey.isEmpty {
                try? keychain.removeAll()
                client = Client()
            }
        }
        
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
    
    /// The configurable OAuth settings. For example: `redirectUrl`, `callbackUrlScheme`
    public var redirectConfig = RedirectConfig()
    
    /// The currently active Session, which is guaranteed to be one of the sessions in Client.sessions. If there is no active session, this field will be null.
    public var session: Session? {
        client.lastActiveSession
    }
    
    /// A shortcut to Session.user which holds the currently active User object. If the session is null or undefined, the user field will match.
    public var user: User? {
        client.lastActiveSession?.user
    }
    
    /// The Client object for the current device.
    @Published internal(set) public var client: Client = .init() {
        didSet {
            Task {
                do {
                    try await PersistenceManager.saveClient(client)
                } catch {
                    dump(error)
                }
            }
        }
    }
    
    /// The Environment for the clerk instance.
    @Published internal(set) public var environment: Clerk.Environment = .init() {
        didSet {
            Task {
                do {
                    try await PersistenceManager.saveEnvironment(environment)
                } catch {
                    dump(error)
                }
            }
        }
    }
    
    /// The retrieved active sessions for this user.
    ///
    /// Is set by the `getSessions` function on a user.
    @Published var sessionsByUserId: [String: [Session]] = .init()
    
    /// The cached session tokens. Key is the session id + template name if there is one.
    /// e.g. `sess_abc12345` or `sess_abc12345-supabase`
    ///
    /// Is set by the `getToken` function on a session.
    var sessionTokensByCacheKey: [String: TokenResource] = .init()
    
    /**
     Signs out the active user from all sessions in a multi-session application, or simply the current session in a single-session context. The current client will be deleted. You can also specify a specific session to sign out by passing the sessionId parameter.
     - Parameter sessionId: Specify a specific session to sign out. Useful for multi-session applications.
     */
    @MainActor
    public func signOut(sessionId: String? = nil) async throws {
        if let sessionId {
            let request = ClerkAPI.v1.client.sessions.id(sessionId).remove.post
            try await Clerk.shared.apiClient.send(request)
            try await Clerk.shared.client.get()
            if Clerk.shared.client.sessions.isEmpty {
                try await Clerk.shared.client.destroy()
            }
        } else {
            try await Clerk.shared.client.destroy()
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
            try await Clerk.shared.client.get()
            
        } else if let currentSession = session {
            try await currentSession.revoke()
            try await Clerk.shared.client.get()
        }
    }
    
    private var sessionPollingTask: Task<Void, Error>?
        
    private func startSessionTokenPolling() {
        sessionPollingTask = Task(priority: .background) {
            repeat {
                if let session {
                    do {
                        try await session.getToken(.init(skipCache: true))
                    } catch {
                        dump(error)
                        sessionPollingTask?.cancel()
                    }
                }
                try await Task.sleep(for: .seconds(50))
            } while sessionPollingTask?.isCancelled == false
        }
    }
    
    /// Loads the data persisted across sessions from the keychain.
    @MainActor
    private func loadPersistedData() async {
        do {
            if let client = try await PersistenceManager.loadClient() {
                self.client = client
            }
        } catch {
            dump(error)
        }
        
        do {
            if let environment = try await PersistenceManager.loadEnvironment() {
                self.environment = environment
            }
        } catch {
            dump(error)
        }
    }
    
    private let imagePrefetcher = ImagePrefetcher(pipeline: .shared, destination: .diskCache)
    
    private func prefetchImages() {
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
}
