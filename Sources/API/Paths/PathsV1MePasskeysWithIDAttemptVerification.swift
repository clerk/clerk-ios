//
//  PathsV1MePasskeysWithIDAttemptVerification.swift
//  Clerk
//
//  Created by Mike Pitre on 9/6/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.MeEndpoint.PasskeysEndpoint.WithIdEndpoint {
    
    var attemptVerification: AttemptVerificationEndpoint {
        AttemptVerificationEndpoint(path: path + "/attempt_verification")
    }
    
    struct AttemptVerificationEndpoint {
        /// Path: `/v1/me/passkeys/{id}`
        let path: String
        
        func post(queryItems: [URLQueryItem] = [], body: any Encodable) -> Request<ClientResponse<Passkey>> {
            .init(path: path, method: .post, query: queryItems.asTuples, body: body)
        }
    }
    
}
