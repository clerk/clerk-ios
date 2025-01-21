//
//  Passkey.swift
//  Clerk
//
//  Created by Mike Pitre on 9/6/24.
//

import Foundation

public struct Passkey: Codable, Identifiable, Equatable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let lastUsedAt: Date?
    public let createdAt: Date
    public let updatedAt: Date
    public let verification: Verification?
}

extension Passkey {
    
    private var nonceJSON: JSON? {
        verification?.nonce?.toJSON()
    }
    
    public var challenge: Data? {
        let challengeString = nonceJSON?["challenge"]?.stringValue
        return challengeString?.dataFromBase64URL()
    }
    
    public var username: String? {
        nonceJSON?["user"]?["name"]?.stringValue
    }
    
    public var userId: Data? {
        nonceJSON?["user"]?["id"]?.stringValue?.base64URLFromBase64String().dataFromBase64URL()
    }
    
}

extension Passkey {
    
    @discardableResult @MainActor
    public static func create() async throws -> Passkey {
        let request = ClerkFAPI.v1.me.passkeys.post(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
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
    
    @discardableResult @MainActor
    public func destroy() async throws -> DeletedObject {
        let request = ClerkFAPI.v1.me.passkeys.withId(id).delete(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
}
