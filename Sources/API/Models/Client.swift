//
//  Client.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

/**
 The Client object keeps track of the authenticated sessions in the current device. The device can be a browser, a native application or any other medium that is usually the requesting part in a request/response architecture.
 The Client object also holds information about any sign in or sign up attempts that might be in progress, tracking the sign in or sign up progress.
 */
public struct Client: Codable {

    /// The current sign in attempt.
    public let signIn: SignIn
    
    /// The current sign up attempt.
    public let signUp: SignUp
    
    /// A list of sessions that have been created on this client.
    public let sessions: [Session]
    
    /// Unique identifier of the last active Session on this client.
    public let lastActiveSessionId: String?
    
    /// Timestamp of last update for the client.
    public let updatedAt: Date
    
    /// A list of active sessions on this client.
    public var activeSessions: [Session] {
        sessions.filter { $0.status == .active }
    }
    
    /// The last active session on this client.
    public var lastActiveSession: Session? {
        sessions.first(where: { $0.id == lastActiveSessionId })
    }
    
    /// Returns true if this client hasn't been saved (created) yet in the Frontend API. Returns false otherwise.
    public let isNew: Bool
    
    enum CodingKeys: CodingKey {
        case signIn
        case signUp
        case sessions
        case lastActiveSessionId
        case updatedAt
    }
    
    init(
        signIn: SignIn = SignIn(),
        signUp: SignUp = SignUp(),
        sessions: [Session] = [],
        lastActiveSessionId: String? = nil,
        updatedAt: Date? = nil
    ) {
        self.signIn = signIn
        self.signUp = signUp
        self.sessions = sessions
        self.lastActiveSessionId = lastActiveSessionId
        self.updatedAt = updatedAt ?? .now
        self.isNew = true
    }
    
    public init(from decoder: Decoder) throws {
        let container: KeyedDecodingContainer<Client.CodingKeys> = try decoder.container(keyedBy: Client.CodingKeys.self)
        self.isNew = false
        
        // SignUp and SignIn can have null values when returned from the api, but should never be nil on the client
        self.signIn = try container.decodeIfPresent(SignIn.self, forKey: Client.CodingKeys.signIn) ?? SignIn()
        self.signUp = try container.decodeIfPresent(SignUp.self, forKey: Client.CodingKeys.signUp) ?? SignUp()
        //
        self.sessions = try container.decode([Session].self, forKey: .sessions)
        self.lastActiveSessionId = try container.decodeIfPresent(String.self, forKey: .lastActiveSessionId)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}

extension Client {
    
    /// Retrieves the current client.
    @MainActor
    func get() async throws {
        let request = ClerkAPI.v1.client.get
        Clerk.shared.client = try await Clerk.apiClient.send(request).value.response ?? Client()
    }
    
    /// Creates a new client for the current instance along with its cookie.
    @MainActor
    public func create() async throws {
        let request = ClerkAPI.v1.client.put
        Clerk.shared.client = try await Clerk.apiClient.send(request).value.response
    }
    
    /// Deletes the client. All sessions will be reset.
    @MainActor
    public func destroy() async throws {
        let request = ClerkAPI.v1.client.delete
        try await Clerk.apiClient.send(request)
        try Clerk.keychain.removeAll()
        Clerk.shared.client = Client()
    }
    
}
