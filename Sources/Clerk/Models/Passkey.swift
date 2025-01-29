//
//  Passkey.swift
//  Clerk
//
//  Created by Mike Pitre on 9/6/24.
//

import Foundation

/// An object that represents a passkey associated with a user.
public struct Passkey: Codable, Identifiable, Equatable, Sendable, Hashable {
    
    /// The unique identifier of the passkey.
    public let id: String
    
    /// The passkey's name.
    public let name: String
    
    /// The verification details for the passkey.
    public let verification: Verification?
    
    /// The date when the passkey was created.
    public let createdAt: Date
    
    /// The date when the passkey was last updated.
    public let updatedAt: Date
    
    /// The date when the passkey was last used.
    public let lastUsedAt: Date?
}

extension Passkey {
    
    /// Creates a new passkey
    @discardableResult @MainActor
    public static func create() async throws -> Passkey {
        let request = ClerkFAPI.v1.me.passkeys.post(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    /// Updates the name of the associated passkey for the signed-in user.
    @discardableResult @MainActor
    public func update(name: String) async throws -> Passkey {
        let request = ClerkFAPI.v1.me.passkeys.withId(id).patch(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
            body: [
                "name": name
            ]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    /// Attempts to verify the passkey with a credential.
    @discardableResult @MainActor
    public func attemptVerification(credential: String) async throws -> Passkey {
        let request = ClerkFAPI.v1.me.passkeys.withId(id).attemptVerification.post(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
            body: [
                "strategy": "passkey",
                "public_key_credential": credential
            ]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    /// Deletes the associated passkey for the signed-in user.
    @discardableResult @MainActor
    public func delete() async throws -> DeletedObject {
        let request = ClerkFAPI.v1.me.passkeys.withId(id).delete(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
}

extension Passkey {
    
    // MARK: - Private Properties
    
    var nonceJSON: JSON? {
        verification?.nonce?.toJSON()
    }
    
    var challenge: Data? {
        let challengeString = nonceJSON?["challenge"]?.stringValue
        return challengeString?.dataFromBase64URL()
    }
    
    var username: String? {
        nonceJSON?["user"]?["name"]?.stringValue
    }
    
    var userId: Data? {
        nonceJSON?["user"]?["id"]?.stringValue?.base64URLFromBase64String().dataFromBase64URL()
    }
    
}
