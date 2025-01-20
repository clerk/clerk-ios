//
//  PathsV1ClientSignInsWithIDPrepareFirstFactor.swift
//  
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.ClientEndpoint.SignInsEndpoint.WithIDEndpoint {
    
    var prepareFirstFactor: PrepareFirstFactorEndpoint {
        PrepareFirstFactorEndpoint(path: path + "/prepare_first_factor")
    }
    
    struct PrepareFirstFactorEndpoint {
        /// Path: `v1/client/sign_ins/{id}/prepare_first_factor`
        let path: String
        
        func post(_ params: SignIn.PrepareFirstFactorParams) -> Request<ClientResponse<SignIn>> {
            .init(path: path, method: .post, body: params)
        }
    }
    
}
