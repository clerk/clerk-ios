//
//  PathsV1MePhoneNumbersWithIDAttemptVerification.swift
//  
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.MeEndpoint.PhoneNumbersEndpoint.WithID {
    
    var attemptVerification: AttemptVerificationEndpoint {
        AttemptVerificationEndpoint(path: path + "/attempt_verification")
    }
    
    struct AttemptVerificationEndpoint {
        /// Path: `v1/me/phone_numbers/{id}/attempt_verification`
        let path: String
        
        func post(queryItems: [URLQueryItem] = [], body: any Encodable) -> Request<ClientResponse<PhoneNumber>> {
            .init(
                path: path,
                method: .post,
                query: queryItems.asTuples,
                body: body
            )
        }
    }
}
