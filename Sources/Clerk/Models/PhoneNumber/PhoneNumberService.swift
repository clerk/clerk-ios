//
//  PhoneNumberService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation
import Get

extension Container {

    var phoneNumberService: Factory<PhoneNumberService> {
        self { PhoneNumberService() }
    }

}

struct PhoneNumberService {

    var create: @MainActor (_ phoneNumber: String) async throws -> PhoneNumber = { phoneNumber in
        let request = Request<ClientResponse<PhoneNumber>>.init(
            path: "/v1/me/phone_numbers",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["phone_number": phoneNumber]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var delete: @MainActor (_ phoneNumberId: String) async throws -> DeletedObject = { phoneNumberId in
        let request = Request<ClientResponse<DeletedObject>>.init(
            path: "/v1/me/phone_numbers/\(phoneNumberId)",
            method: .delete,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var prepareVerification: @MainActor (_ phoneNumberId: String) async throws -> PhoneNumber = { phoneNumberId in
        let request = Request<ClientResponse<PhoneNumber>>.init(
            path: "/v1/me/phone_numbers/\(phoneNumberId)/prepare_verification",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["strategy": "phone_code"]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var attemptVerification: @MainActor (_ phoneNumberId: String, _ code: String) async throws -> PhoneNumber = { phoneNumberId, code in
        let request = Request<ClientResponse<PhoneNumber>>.init(
            path: "/v1/me/phone_numbers/\(phoneNumberId)/attempt_verification",
            method: .post,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["code": code]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var makeDefaultSecondFactor: @MainActor (_ phoneNumberId: String) async throws -> PhoneNumber = { phoneNumberId in
        let request = Request<ClientResponse<PhoneNumber>>.init(
            path: "/v1/me/phone_numbers/\(phoneNumberId)",
            method: .patch,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["default_second_factor": true]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

    var setReservedForSecondFactor: @MainActor (_ phoneNumberId: String, _ reserved: Bool) async throws -> PhoneNumber = { phoneNumberId, reserved in
        let request = Request<ClientResponse<PhoneNumber>>.init(
            path: "/v1/me/phone_numbers/\(phoneNumberId)",
            method: .patch,
            query: [("_clerk_session_id", value: Clerk.shared.session?.id)],
            body: ["reserved_for_second_factor": reserved]
        )
        
        return try await Container.shared.apiClient().send(request).value.response
    }

}
