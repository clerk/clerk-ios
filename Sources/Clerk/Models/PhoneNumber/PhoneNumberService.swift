//
//  PhoneNumberService.swift
//  Clerk
//
//  Created by Mike Pitre on 7/28/25.
//

import FactoryKit
import Foundation

extension Container {

    var phoneNumberService: Factory<PhoneNumberService> {
        self { @MainActor in PhoneNumberService() }
    }

}

@MainActor
struct PhoneNumberService {

    var create: (_ phoneNumber: String) async throws -> PhoneNumber = { phoneNumber in
        try await Container.shared.apiClient().request()
            .add(path: "/v1/me/phone_numbers")
            .method(.post)
            .addClerkSessionId()
            .body(formEncode: ["phone_number": phoneNumber])
            .data(type: ClientResponse<PhoneNumber>.self)
            .async()
            .response
    }

    var delete: (_ phoneNumberId: String) async throws -> DeletedObject = { phoneNumberId in
        try await Container.shared.apiClient().request()
            .add(path: "/v1/me/phone_numbers/\(phoneNumberId)")
            .method(.delete)
            .addClerkSessionId()
            .data(type: ClientResponse<DeletedObject>.self)
            .async()
            .response
    }

    var prepareVerification: (_ phoneNumberId: String) async throws -> PhoneNumber = { phoneNumberId in
        try await Container.shared.apiClient().request()
            .add(path: "/v1/me/phone_numbers/\(phoneNumberId)/prepare_verification")
            .method(.post)
            .addClerkSessionId()
            .body(formEncode: ["strategy": "phone_code"])
            .data(type: ClientResponse<PhoneNumber>.self)
            .async()
            .response
    }

    var attemptVerification: (_ phoneNumberId: String, _ code: String) async throws -> PhoneNumber = { phoneNumberId, code in
        try await Container.shared.apiClient().request()
            .add(path: "/v1/me/phone_numbers/\(phoneNumberId)/attempt_verification")
            .method(.post)
            .addClerkSessionId()
            .body(formEncode: ["code": code])
            .data(type: ClientResponse<PhoneNumber>.self)
            .async()
            .response
    }

    var makeDefaultSecondFactor: (_ phoneNumberId: String) async throws -> PhoneNumber = { phoneNumberId in
        try await Container.shared.apiClient().request()
            .add(path: "/v1/me/phone_numbers/\(phoneNumberId)")
            .method(.patch)
            .addClerkSessionId()
            .body(formEncode: ["default_second_factor": true])
            .data(type: ClientResponse<PhoneNumber>.self)
            .async()
            .response
    }

    var setReservedForSecondFactor: (_ phoneNumberId: String, _ reserved: Bool) async throws -> PhoneNumber = { phoneNumberId, reserved in
        try await Container.shared.apiClient().request()
            .add(path: "/v1/me/phone_numbers/\(phoneNumberId)")
            .method(.patch)
            .addClerkSessionId()
            .body(formEncode: ["reserved_for_second_factor": reserved])
            .data(type: ClientResponse<PhoneNumber>.self)
            .async()
            .response
    }

}
