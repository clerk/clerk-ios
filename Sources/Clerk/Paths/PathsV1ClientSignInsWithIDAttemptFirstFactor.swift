//
//  PathsV1ClientSignInsWithIDAttemptFirstFactor.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.ClientEndpoint.SignInsEndpoint.WithIDEndpoint {
    
    var attemptFirstFactor: AttemptFirstFactorEndpoint {
        AttemptFirstFactorEndpoint(path: path + "/attempt_first_factor")
    }
    
    struct AttemptFirstFactorEndpoint {
        /// Path: `v1/client/sign_ins/{id}/attempt_first_factor`
        let path: String
        
        func post(body: any Encodable) -> Request<ClientResponse<SignIn>> {
            .init(path: path, method: .post, body: body)
        }
    }
    
}
