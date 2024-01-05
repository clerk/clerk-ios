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
 This is the main entrypoint class for the clerk-ios package. It contains a number of methods and properties for interacting with the Clerk API.
 
 Holds a `.shared` instance.
 */
final public class Clerk: ObservableObject {
    
    /// The shared clerk instance
    public static let shared = Container.shared.clerk()
    
    /**
     Configures the settings for the Clerk package.
     
     To use the Clerk package, you'll need to copy your Publishable Key from the API Keys page in the Clerk Dashboard.
     On this same page, click on the Advanced dropdown and copy your Frontend API URL.
     If you are signed into your Clerk Dashboard, your Publishable key should be visible.
     
     - Parameters:
     - publishableKey: Formatted as pk_test_ in development and pk_live_ in production.
     
     - Note:
     It's essential to call this function with the appropriate values before using any other package functionality.
     Failure to configure the package may result in unexpected behavior or errors.
     
     Example Usage:
     ```swift
     Clerk.shared.configure(publishableKey: "pk_your_publishable_key")
     */
    public func configure(publishableKey: String) {
        self.publishableKey = publishableKey
        loadPersistedData()
        startSessionTokenPolling()
    }
    
    /// Publishable Key: Formatted as pk_test_ in development and pk_live_ in production.
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
            
            if
                let match = publishableKey.firstMatch(of: liveRegex)?.output.1 ?? publishableKey.firstMatch(of: testRegex)?.output.1,
                let apiUrl = String(match).base64Decoded()
            {
                frontendAPIURL = "https://\(apiUrl)"
            }
        }
    }
    
    /// Frontend API URL
    private(set) public var frontendAPIURL: String = ""
    
    /// The Client object for the current device.
    @Published internal(set) public var client: Client = .init() {
        didSet {
            do {
                Clerk.keychain[data: Clerk.KeychainKey.client] = try JSONEncoder.clerkEncoder.encode(client)
            } catch {
                dump(error)
            }
        }
    }
    
    /// The Environment for the clerk instance.
    @Published internal(set) public var environment: Clerk.Environment = .init() {
        didSet {
            do {
                Clerk.keychain[data: Clerk.KeychainKey.environment] = try JSONEncoder.clerkEncoder.encode(environment)
            } catch {
                dump(error)
            }
        }
    }
    
    /// The retrieved active sessions for this user.
    ///
    /// Is set by the `getSessions` function on a user.
    @Published internal(set) public var sessionsByUserId: [String: [Session]] = .init() {
        didSet {
            do {
                Clerk.keychain[data: Clerk.KeychainKey.sessionsByUserId] = try JSONEncoder.clerkEncoder.encode(sessionsByUserId)
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
                Clerk.keychain[data: Clerk.KeychainKey.sessionTokensByCacheKey] = try JSONEncoder.clerkEncoder.encode(sessionTokensByCacheKey)
            } catch {
                dump(error)
            }
        }
    }
}

extension Clerk {
    
    public var session: Session? {
        client.lastActiveSession
    }
    
    public var user: User? {
        client.lastActiveSession?.user
    }
    
    public func startSessionTokenPolling() {
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
    
    /**
     Signs out the active user from all sessions in a multi-session application, or simply the current session in a single-session context. The current client will be deleted. You can also specify a specific session to sign out by passing the sessionId parameter.
     - Parameter sessionId: Specify a specific session to sign out. Useful for multi-session applications.
     */
    public func signOut(sessionId: String? = nil) async throws {
        if let sessionId {
            let request = APIEndpoint
                .v1
                .client
                .sessions
                .id(sessionId)
                .remove
                .post
            
            try await Clerk.apiClient.send(request)
            try await Clerk.shared.client.get()
            if Clerk.shared.client.sessions.isEmpty {
                try await Clerk.shared.client.destroy()
            }
        } else {
            try await Clerk.shared.client.destroy()
        }
    }
    
    public struct SetActiveParams: Encodable {
        public init(
            sessionId: String? = nil,
            organizationId: String? = nil
        ) {
            self.sessionId = sessionId
            self.organizationId = organizationId
        }
        
        /// The session ID to be set as active. If null, the current session is deleted.
        var sessionId: String?
        /// The organization ID to be set as active in the current session. If null, the currently active organization is removed as active.
        var organizationId: String?
    }
    
    /// A method used to set the active session and/or organization.
    public func setActive(_ params: SetActiveParams) async throws {
        guard let sessionId = params.sessionId else {
            // TODO: Delete Session if sessionId is nil
            return
        }
        
        let request = APIEndpoint
            .v1
            .client
            .sessions
            .id(sessionId)
            .touch
            .post(params)
        
        try await Clerk.apiClient.send(request)
        try await Clerk.shared.client.get()
    }
    
}

extension Container {
    
    public var clerk: Factory<Clerk> {
        self { Clerk() }
            .singleton
    }
    
}

extension Clerk {
    
    private func loadPersistedData() {
        
        do {
            if let data = Clerk.keychain[data: Clerk.KeychainKey.client] {
                self.client = try JSONDecoder.clerkDecoder.decode(Client.self, from: data)
            }
        } catch {
            dump(error)
        }
        
        do {
            if let data = Clerk.keychain[data: Clerk.KeychainKey.environment] {
                self.environment = try JSONDecoder.clerkDecoder.decode(Environment.self, from: data)
            }
        } catch {
            dump(error)
        }
        
        do {
            if let data = Clerk.keychain[data: Clerk.KeychainKey.sessionTokensByCacheKey] {
                self.sessionTokensByCacheKey = try JSONDecoder.clerkDecoder.decode([String: TokenResource].self, from: data)
            }
        } catch {
            dump(error)
        }
        
        do {
            if let data = Clerk.keychain[data: Clerk.KeychainKey.sessionsByUserId] {
                self.sessionsByUserId = try JSONDecoder.clerkDecoder.decode([String: [Session]].self, from: data)
            }
        } catch {
            dump(error)
        }
    }
    
}
