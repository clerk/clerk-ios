//
//  PathsV1ClientSignInsWithIDPrepareSecondFactor.swift
//  
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.ClientEndpoint.SignInsEndpoint.WithIdEndpoint {
    
    var prepareSecondFactor: PrepareSecondFactorEndpoint {
        PrepareSecondFactorEndpoint(path: path + "/prepare_second_factor")
    }
    
    struct PrepareSecondFactorEndpoint {
        /// Path: `v1/client/sign_ins/{id}/prepare_second_factor`
        let path: String
        
        func post(_ params: SignIn.PrepareSecondFactorParams) -> Request<ClientResponse<SignIn>> {
            .init(path: path, method: .post, body: params)
        }
    }
    
}
