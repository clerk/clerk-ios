//
//  Client.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import SimpleKeychain

/// The Client object keeps track of the authenticated sessions in the current device. The device can be a browser, a native application or any other medium that is usually the requesting part in a request/response architecture.
///
/// The Client object also holds information about any sign in or sign up attempts that might be in progress, tracking the sign in or sign up progress.
public struct Client: Codable, Sendable, Equatable {
    
    /// Unique identifier for this client.
    public let id: String
    
    /// The current sign in attempt, or nil if there is none.
    public let signIn: SignIn?
    
    /// The current sign up attempt, or nil if there is none.
    public let signUp: SignUp?
    
    /// A list of sessions that have been created on this client.
    public let sessions: [Session]
    
    /// A list of active sessions on this client.
    public var activeSessions: [Session] {
        sessions.filter { $0.status == .active }
    }
    
    /// The ID of the last active Session on this client.
    public let lastActiveSessionId: String?
    
    /// Timestamp of last update for the client.
    public let updatedAt: Date
    
}

extension Client {
    
    /// Retrieves the current client.
    @discardableResult @MainActor
    static func get() async throws -> Client? {
        let request = ClerkFAPI.v1.client.get
        let client = try await Clerk.shared.apiClient.send(request).value.response
        Clerk.shared.client = client
        return client
    }
    
}


/// The ClerkAPI oftens returns the requested object along with the Client Object (piggy-backed).
///
/// This wrapper object can be used to decode the requested object along with the client object.
/// ### Example
/// ```swift
/// func post(_ params: SignUp.CreateParams) -> Request<ClientResponse<SignUp>>
/// ```
struct ClientResponse<Response: Decodable & Sendable>: Decodable, Sendable {
    let response: Response
    let client: Client?
}
