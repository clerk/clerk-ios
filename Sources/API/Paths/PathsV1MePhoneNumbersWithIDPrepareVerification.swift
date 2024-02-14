//
//  PathsV1MePhoneNumbersWithIDPrepareVerification.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.MeEndpoint.PhoneNumbersEndpoint.WithID {
    
    var prepareVerification: PrepareVerificationEndpoint {
        PrepareVerificationEndpoint(path: path + "/prepare_verification")
    }
    
    struct PrepareVerificationEndpoint {
        /// Path: `v1/me/phone_numbers/{id}/prepare_verification`
        let path: String
        
        var post: Request<ClientResponse<PhoneNumber>> {
            .init(path: path, method: .post, body: ["strategy": "phone_code"])
        }
    }
}
