//
//  PathsV1ClientSignIns.swift
//  
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.ClientEndpoint {
    
    var signIns: SignInsEndpoint {
        SignInsEndpoint(path: path + "/sign_ins")
    }
    
    struct SignInsEndpoint {
        /// Path: `v1/client/sign_ins`
        let path: String
        
        func post(_ params: SignIn.CreateParams) -> Request<ClientResponse<SignIn>> {
            .init(path: path, method: .post, body: params)
        }
    }
    
}
