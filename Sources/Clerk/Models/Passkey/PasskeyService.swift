//
//  PasskeyService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation

extension Container {

    var passkeyService: Factory<PasskeyService> {
        self { @MainActor in PasskeyService() }
    }

}

@MainActor
struct PasskeyService {

    var create: () async throws -> Passkey = {
        try await Container.shared.apiClient().request()
            .add(path: "/v1/me/passkeys")
            .method(.post)
            .addClerkSessionId()
            .data(type: ClientResponse<Passkey>.self)
            .async()
            .response
    }

    var update: (_ passkeyId: String, _ name: String) async throws -> Passkey = { passkeyId, name in
        try await Container.shared.apiClient().request()
            .add(path: "/v1/me/passkeys/\(passkeyId)")
            .method(.patch)
            .addClerkSessionId()
            .body(formEncode: ["name": name])
            .data(type: ClientResponse<Passkey>.self)
            .async()
            .response
    }

    var attemptVerification: (_ passkeyId: String, _ credential: String) async throws -> Passkey = { passkeyId, credential in
        try await Container.shared.apiClient().request()
            .add(path: "/v1/me/passkeys/\(passkeyId)/attempt_verification")
            .method(.post)
            .addClerkSessionId()
            .body(formEncode: [
                "strategy": "passkey",
                "public_key_credential": credential
            ])
            .data(type: ClientResponse<Passkey>.self)
            .async()
            .response
    }

    var delete: (_ passkeyId: String) async throws -> DeletedObject = { passkeyId in
        try await Container.shared.apiClient().request()
            .add(path: "/v1/me/passkeys/\(passkeyId)")
            .method(.delete)
            .addClerkSessionId()
            .data(type: ClientResponse<DeletedObject>.self)
            .async()
            .response
    }

}
