//
//  PathsV1ClientSignUps.swift
//  
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.ClientEndpoint {
    
    var signUps: SignUpsEndpoint {
        SignUpsEndpoint(path: path + "/sign_ups")
    }
    
    struct SignUpsEndpoint {
        /// Path: `v1/client/sign_ups`
        let path: String
        
        var get: Request<ClientResponse<SignUp>> {
            .init(path: path)
        }
        
        func post(_ body: any Encodable) -> Request<ClientResponse<SignUp>> {
            .init(path: path, method: .post, body: body)
        }
    }
}
