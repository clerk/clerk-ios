//
//  PasskeyService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation
import Get

extension Container {

    var passkeyService: Factory<PasskeyService> {
        self { PasskeyService() }
    }

}

struct PasskeyService {

    var create: @MainActor () async throws -> Passkey = {
        let request = Request<ClientResponse<Passkey>>.init(
            path: "/v1/me/passkeys",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var update: @MainActor (_ passkeyId: String, _ name: String) async throws -> Passkey = { passkeyId, name in
        let request = Request<ClientResponse<Passkey>>.init(
            path: "/v1/me/passkeys/\(passkeyId)",
            method: .patch,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["name": name]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var attemptVerification: @MainActor (_ passkeyId: String, _ credential: String) async throws -> Passkey = { passkeyId, credential in
        let request = Request<ClientResponse<Passkey>>.init(
            path: "/v1/me/passkeys/\(passkeyId)/attempt_verification",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: [
                "strategy": "passkey",
                "public_key_credential": credential
            ]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var delete: @MainActor (_ passkeyId: String) async throws -> DeletedObject = { passkeyId in
        let request = Request<ClientResponse<DeletedObject>>.init(
            path: "/v1/me/passkeys/\(passkeyId)",
            method: .delete,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

}
