//
//  Client.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import SimpleKeychain

/**
 The Client object keeps track of the authenticated sessions in the current device. The device can be a browser, a native application or any other medium that is usually the requesting part in a request/response architecture.
 The Client object also holds information about any sign in or sign up attempts that might be in progress, tracking the sign in or sign up progress.
 */
public struct Client: Codable, Sendable, Equatable {
    
    public let id: String

    /// The current sign in attempt.
    public let signIn: SignIn?
    
    /// The current sign up attempt.
    public let signUp: SignUp?
    
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
    
}

extension Client {
    
    /// Retrieves the current client.
    @discardableResult @MainActor
    public static func get() async throws -> Client? {
        let request = ClerkFAPI.v1.client.get
        let client = try await Clerk.shared.apiClient.send(request).value.response
        Clerk.shared.client = client
        return client
    }
    
    /// Retrieves the current client.
    @discardableResult @MainActor
    public func get() async throws -> Client? {
        try await Client.get()
    }
    
    /// Creates a new client for the current instance.
    @discardableResult @MainActor
    static func create() async throws -> Client {
        let request = ClerkFAPI.v1.client.put
        let client = try await Clerk.shared.apiClient.send(request).value.response
        Clerk.shared.client = client
        return client
    }
    
    /// Fetches the client from the server, if one doesn't exist for the device then create one.
    @discardableResult @MainActor
    static func getOrCreate() async throws -> Client? {
        let client = try await Client.get()
        if let client {
            return client
        } else {
            return try await Client.create()
        }
    }
    
}
