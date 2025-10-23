//
//  EmailAddressService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation
import Get

extension Container {

    var emailAddressService: Factory<EmailAddressService> {
        self { EmailAddressService() }
    }

}

struct EmailAddressService {

    var create: @MainActor (_ email: String) async throws -> EmailAddress = { email in
        let request = Request<ClientResponse<EmailAddress>>(
            path: "v1/me/email_addresses",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["email_address": email]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var prepareVerification: @MainActor (_ emailAddressId: String, _ strategy: EmailAddress.PrepareStrategy) async throws -> EmailAddress = { emailAddressId, strategy in
        let request = Request<ClientResponse<EmailAddress>>(
            path: "/v1/me/email_addresses/\(emailAddressId)/prepare_verification",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: strategy.requestBody
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var attemptVerification: @MainActor (_ emailAddressId: String, _ strategy: EmailAddress.AttemptStrategy) async throws -> EmailAddress = { emailAddressId, strategy in
        let request = Request<ClientResponse<EmailAddress>>(
            path: "/v1/me/email_addresses/\(emailAddressId)/attempt_verification",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: strategy.requestBody
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var destroy: @MainActor (_ emailAddressId: String) async throws -> DeletedObject = { emailAddressId in
        let request = Request<ClientResponse<DeletedObject>>(
            path: "/v1/me/email_addresses/\(emailAddressId)",
            method: .delete,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

}
