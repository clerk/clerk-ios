//
//  Clerk.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import Factory
import RegexBuilder

/**
 This is the main entrypoint class for the clerk package. It contains a number of methods and properties for interacting with the Clerk API.
 */
final public class Clerk: ObservableObject {
    public static let shared = Container.shared.clerk()
    static let apiClient = Container.shared.apiClient()
    static let keychain = Container.shared.keychain()
    
    init() {}
    
    /// Create an instance of the Clerk class with dedicated options.
    /// - Parameter publishableKey: The publishable key from your Clerk Dashboard, used to connect to Clerk.
    ///
    /// Initializes the Clerk object and loads all necessary environment configuration and instance settings from the Frontend API.
    /// It is absolutely necessary to call this method before using the Clerk object in your code.
    public func load(publishableKey: String) async {
        self.publishableKey = publishableKey
        await loadPersistedData()
        startSessionTokenPolling()
        
        Task.detached { [client] in
            do {
                if !client.isNew {
                    try await client.get()
                } else {
                    try await client.create()
                }
            } catch {
                dump(error)
            }
        }
        
        Task.detached { [environment] in
            do {
                try await environment.get()
            } catch {
                dump(error)
            }
        }
    }
    
    /// The publishable key from your Clerk Dashboard, used to connect to Clerk.
    private(set) public var publishableKey: String = "" {
        didSet {
            let liveRegex = Regex {
                "pk_live_"
                Capture {
                    OneOrMore(.any)
                }
                "k"
            }
            
            let testRegex = Regex {
                "pk_test_"
                Capture {
                    OneOrMore(.any)
                }
                "k"
            }
            
            if let match = publishableKey.firstMatch(of: liveRegex)?.output.1 ?? publishableKey.firstMatch(of: testRegex)?.output.1,
               let apiUrl = String(match).base64Decoded() {
                frontendAPIURL = "https://\(apiUrl)"
            }
        }
    }
    
    /// Frontend API URL
    private(set) public var frontendAPIURL: String = ""
    
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
            do {
                Clerk.keychain[data: ClerkKeychainKey.client] = try JSONEncoder.clerkEncoder.encode(client)
            } catch {
                dump(error)
            }
        }
    }
    
    /// The Environment for the clerk instance.
    @Published internal(set) public var environment: Clerk.Environment = .init() {
        didSet {
            do {
                Clerk.keychain[data: ClerkKeychainKey.environment] = try JSONEncoder.clerkEncoder.encode(environment)
            } catch {
                dump(error)
            }
        }
    }
    
    /// The retrieved active sessions for this user.
    ///
    /// Is set by the `getSessions` function on a user.
    @Published var sessionsByUserId: [String: [Session]] = .init() {
        didSet {
            do {
                Clerk.keychain[data: ClerkKeychainKey.sessionsByUserId] = try JSONEncoder.clerkEncoder.encode(sessionsByUserId)
            } catch {
                dump(error)
            }
        }
    }
    
    /// The cached session tokens. Key is the session id + template name if there is one.
    /// e.g. `sess_abc12345` or `sess_abc12345-supabase`
    ///
    /// Is set by the `getToken` function on a session.
    var sessionTokensByCacheKey: [String: TokenResource] = .init() {
        didSet {
            do {
                Clerk.keychain[data: ClerkKeychainKey.sessionTokensByCacheKey] = try JSONEncoder.clerkEncoder.encode(sessionTokensByCacheKey)
            } catch {
                dump(error)
            }
        }
    }
    
    /**
     Signs out the active user from all sessions in a multi-session application, or simply the current session in a single-session context. The current client will be deleted. You can also specify a specific session to sign out by passing the sessionId parameter.
     - Parameter sessionId: Specify a specific session to sign out. Useful for multi-session applications.
     */
    public func signOut(sessionId: String? = nil) async throws {
        if let sessionId {
            let request = ClerkAPI.v1.client.sessions.id(sessionId).remove.post
            try await Clerk.apiClient.send(request)
            try await Clerk.shared.client.get()
            if Clerk.shared.client.sessions.isEmpty {
                try await Clerk.shared.client.destroy()
            }
        } else {
            try await Clerk.shared.client.destroy()
        }
    }
    
    /// A method used to set the active session and/or organization.
    public func setActive(_ params: SetActiveParams) async throws {
        if let sessionId = params.sessionId {
            let request = ClerkAPI.v1.client.sessions.id(sessionId).touch.post(params)
            try await Clerk.apiClient.send(request)
            try await Clerk.shared.client.get()
            
        } else if let currentSession = session {
            try await currentSession.revoke()
            try await Clerk.shared.client.get()
        }
    }
    
    public struct SetActiveParams: Encodable {
        /// The session ID to be set as active. If null, the current session is deleted.
        var sessionId: String?
        /// The organization ID to be set as active in the current session. If null, the currently active organization is removed as active.
        var organizationId: String?
    }
    
    private func startSessionTokenPolling() {
        Timer.scheduledTimer(withTimeInterval: 50, repeats: true) { _ in
            Task(priority: .background) { [weak self] in
                guard let self, let session else { return }
                
                do {
                    try await session.getToken(.init(skipCache: true))
                } catch {
                    dump(error)
                }
            }
        }
    }
    
    /// Loads the data persisted across sessions from the keychain.
    @MainActor
    private func loadPersistedData() {
        
        if let data = Clerk.keychain[data: ClerkKeychainKey.client] {
            do {
                self.client = try JSONDecoder.clerkDecoder.decode(Client.self, from: data)
            } catch {
                dump(error)
            }
        }
        
        if let data = Clerk.keychain[data: ClerkKeychainKey.environment] {
            do {
                self.environment = try JSONDecoder.clerkDecoder.decode(Environment.self, from: data)
            } catch {
                dump(error)
            }
        }
        
        if let data = Clerk.keychain[data: ClerkKeychainKey.sessionTokensByCacheKey] {
            do {
                self.sessionTokensByCacheKey = try JSONDecoder.clerkDecoder.decode([String: TokenResource].self, from: data)
            } catch {
                dump(error)
            }
        }
        
        if let data = Clerk.keychain[data: ClerkKeychainKey.sessionsByUserId] {
            do {
                self.sessionsByUserId = try JSONDecoder.clerkDecoder.decode([String: [Session]].self, from: data)
            } catch {
                dump(error)
            }
        }
    }
}
