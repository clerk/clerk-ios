//
//  PathsV1MeEmailAddressesWithIDPrepareVerification.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.MeEndpoint.EmailAddressesEndpoint.WithIdEndpoint {
    
    var prepareVerification: PrepareVerificationEndpoint {
        PrepareVerificationEndpoint(path: path + "/prepare_verification")
    }
    
    struct PrepareVerificationEndpoint {
        /// Path: `v1/me/email_addresses/{id}/prepare_verification`
        let path: String
        
        func post(queryItems: [URLQueryItem] = [], body: any Encodable) -> Request<ClientResponse<EmailAddress>> {
            .init(path: path, method: .post, query: queryItems.asTuples, body: body)
        }
    }
}
