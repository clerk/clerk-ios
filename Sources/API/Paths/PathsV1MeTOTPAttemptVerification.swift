//
//  PathsV1MeTOTPAttemptVerification.swift
//
//
//  Created by Mike Pitre on 2/13/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.MeEndpoint.TOTPEndpoint {
    
    var attemptVerification: AttemptVerificationEndpoint {
        AttemptVerificationEndpoint(path: path + "/attempt_verification")
    }
    
    struct AttemptVerificationEndpoint {
        /// Path: `v1/me/totp/attempt_verification`
        let path: String
        
        func post(code: String) -> Request<ClientResponse<TOTPResource>> {
            .init(path: path, method: .post, body: ["code": code])
        }
    }
    
}
