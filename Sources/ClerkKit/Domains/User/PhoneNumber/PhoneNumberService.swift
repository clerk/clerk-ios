//
//  PhoneNumberService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation

extension Container {

    var phoneNumberService: Factory<PhoneNumberServiceProtocol> {
        self { PhoneNumberService() }
    }

}

protocol PhoneNumberServiceProtocol: Sendable {
    @MainActor func create(_ phoneNumber: String) async throws -> PhoneNumber
    @MainActor func delete(_ phoneNumberId: String) async throws -> DeletedObject
    @MainActor func prepareVerification(_ phoneNumberId: String) async throws -> PhoneNumber
    @MainActor func attemptVerification(_ phoneNumberId: String, _ code: String) async throws -> PhoneNumber
    @MainActor func makeDefaultSecondFactor(_ phoneNumberId: String) async throws -> PhoneNumber
    @MainActor func setReservedForSecondFactor(_ phoneNumberId: String, reserved: Bool) async throws -> PhoneNumber
}

final class PhoneNumberService: PhoneNumberServiceProtocol {

    private var apiClient: APIClient { Container.shared.apiClient() }

    @MainActor
    func create(_ phoneNumber: String) async throws -> PhoneNumber {
        let request = Request<ClientResponse<PhoneNumber>>(
            path: "/v1/me/phone_numbers",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["phone_number": phoneNumber]
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func delete(_ phoneNumberId: String) async throws -> DeletedObject {
        let request = Request<ClientResponse<DeletedObject>>(
            path: "/v1/me/phone_numbers/\(phoneNumberId)",
            method: .delete,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func prepareVerification(_ phoneNumberId: String) async throws -> PhoneNumber {
        let request = Request<ClientResponse<PhoneNumber>>(
            path: "/v1/me/phone_numbers/\(phoneNumberId)/prepare_verification",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["strategy": "phone_code"]
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func attemptVerification(_ phoneNumberId: String, _ code: String) async throws -> PhoneNumber {
        let request = Request<ClientResponse<PhoneNumber>>(
            path: "/v1/me/phone_numbers/\(phoneNumberId)/attempt_verification",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["code": code]
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func makeDefaultSecondFactor(_ phoneNumberId: String) async throws -> PhoneNumber {
        let request = Request<ClientResponse<PhoneNumber>>(
            path: "/v1/me/phone_numbers/\(phoneNumberId)",
            method: .patch,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["default_second_factor": true]
        )

        return try await apiClient.send(request).value.response
    }

    @MainActor
    func setReservedForSecondFactor(_ phoneNumberId: String, reserved: Bool) async throws -> PhoneNumber {
        let request = Request<ClientResponse<PhoneNumber>>(
            path: "/v1/me/phone_numbers/\(phoneNumberId)",
            method: .patch,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["reserved_for_second_factor": reserved]
        )

        return try await apiClient.send(request).value.response
    }
}
