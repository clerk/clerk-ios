//
//  PathsV1ClientSignUpsWithIDAttemptVerification.swift
//  
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.ClientEndpoint.SignUpsEndpoint.WithID {
    
    var attemptVerification: AttemptVerificationEndpoint {
        AttemptVerificationEndpoint(path: path + "/attempt_verification")
    }
    
    struct AttemptVerificationEndpoint {
        /// Path: `v1/client/sign_ups/{id}/attempt_verification`
        let path: String
        
        func post(_ params: SignUp.AttemptVerificationParams) -> Request<ClientResponse<SignUp>> {
            .init(path: path, method: .post, body: params)
        }
    }
}
