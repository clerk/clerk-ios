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

    var emailAddressService: Factory<EmailAddressServiceProtocol> {
        self { EmailAddressService() }
    }

}

protocol EmailAddressServiceProtocol: Sendable {
    @MainActor func create(_ email: String) async throws -> EmailAddress
    @MainActor func prepareVerification(_ emailAddressId: String, _ strategy: EmailAddress.PrepareStrategy) async throws -> EmailAddress
    @MainActor func attemptVerification(_ emailAddressId: String, _ strategy: EmailAddress.AttemptStrategy) async throws -> EmailAddress
    @MainActor func destroy(_ emailAddressId: String) async throws -> DeletedObject
}

final class EmailAddressService: EmailAddressServiceProtocol {

    private var apiClient: APIClient { Container.shared.apiClient() }

    @MainActor
    func create(_ email: String) async throws -> EmailAddress {
        let request = Request<ClientResponse<EmailAddress>>(
            path: "v1/me/email_addresses",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["email_address": email]
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func prepareVerification(_ emailAddressId: String, _ strategy: EmailAddress.PrepareStrategy) async throws -> EmailAddress {
        let request = Request<ClientResponse<EmailAddress>>(
            path: "/v1/me/email_addresses/\(emailAddressId)/prepare_verification",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: strategy.requestBody
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func attemptVerification(_ emailAddressId: String, _ strategy: EmailAddress.AttemptStrategy) async throws -> EmailAddress {
        let request = Request<ClientResponse<EmailAddress>>(
            path: "/v1/me/email_addresses/\(emailAddressId)/attempt_verification",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: strategy.requestBody
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func destroy(_ emailAddressId: String) async throws -> DeletedObject {
        let request = Request<ClientResponse<DeletedObject>>(
            path: "/v1/me/email_addresses/\(emailAddressId)",
            method: .delete,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )

        return try await apiClient.send(request).value.response
    }
}
