//
//  Passkey.swift
//  Clerk
//
//  Created by Mike Pitre on 9/6/24.
//

import Foundation

public struct Passkey: Codable {
    let id: String
    let name: String
    let lastUsedAt: Date?
    let createdAt: Date
    let updatedAt: Date
    let verification: Verification?
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
