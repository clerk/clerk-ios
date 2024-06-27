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
    
    let id: String

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
    
    /// Creates a new client for the current instance along with its cookie.
    @discardableResult @MainActor
    static func create() async throws -> Client {
        let request = ClerkAPI.v1.client.put
        let client = try await Clerk.shared.apiClient.send(request).value.response
        Clerk.shared.client = client
        return client
    }
    
    /// Retrieves the current client.
    @discardableResult @MainActor
    public static func get() async throws -> Client? {
        let request = ClerkAPI.v1.client.get
        let client = try await Clerk.shared.apiClient.send(request).value.response
        Clerk.shared.client = client
        return client
    }
    
    /// Retrieves the current client.
    @discardableResult @MainActor
    public func get() async throws -> Client? {
        try await Client.get()
    }
    
    /// Deletes the client. All sessions will be reset.
    @discardableResult @MainActor
    func destroy() async throws -> Client? {
        let request = ClerkAPI.v1.client.delete
        let client = try await Clerk.shared.apiClient.send(request).value.response
        try await Client.get()
        return client
    }
    
    /**
     Use this method to kick-off the sign in flow. It creates a SignIn object and stores the sign-in lifecycle state.
     
     Depending on the use-case and the params you pass to the create method, it can either complete the sign-in process in one go, or simply collect part of the necessary data for completing authentication at a later stage.
     */
    @discardableResult @MainActor
    public func createSignIn(strategy: SignIn.CreateStrategy) async throws -> SignIn {
        try await SignIn.create(strategy: strategy)
    }
    
    /**
     This method initiates a new sign-up flow. It creates a new `SignUp` object and de-activates any existing `SignUp` that the client might already had in progress.
     
     Choices on the instance settings affect which options are available to use.
     
     This sign up might be complete if you supply the required fields in one go.
     However, this is not mandatory. Our sign-up process provides great flexibility and allows users to easily create multi-step sign-up flows.
     */
    @discardableResult @MainActor
    public func createSignUp(strategy: SignUp.CreateStrategy) async throws -> SignUp {
        try await SignUp.create(strategy: strategy)
    }
    
}
