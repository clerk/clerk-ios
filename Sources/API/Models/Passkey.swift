//
//  Passkey.swift
//  Clerk
//
//  Created by Mike Pitre on 9/6/24.
//

import Foundation

public struct Passkey: Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let lastUsedAt: Date?
    public let createdAt: Date
    public let updatedAt: Date
    public let verification: Verification?
}

extension Passkey {
    
    @discardableResult @MainActor
    static func create() async throws -> Passkey {
        let request = ClerkAPI.v1.me.passkeys.post(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
    @discardableResult @MainActor
    func attemptVerification(credential: String) async throws -> Passkey {
        let request = ClerkAPI.v1.me.passkeys.withId(id).attemptVerification.post(
            queryItems: [.init(name: "_clerk_session_id", value: Clerk.shared.session?.id)],
            body: [
                "strategy": Strategy.passkey.stringValue,
                "public_key_credential": credential
            ]
        )
        
        let response = try await Clerk.shared.apiClient.send(request)
        Clerk.shared.client = response.value.client
        return response.value.response
    }
    
}

extension Passkey {
    
    static var mock: Passkey {
        .init(
            id: UUID().uuidString,
            name: "iCloud Keychain",
            lastUsedAt: .now,
            createdAt: .now,
            updatedAt: .now,
            verification: .init(
                status: .verified,
                strategy: Strategy.passkey.stringValue,
                attempts: 0,
                expireAt: .now,
                error: nil,
                nonce: nil
            )
        )
    }
    
}
