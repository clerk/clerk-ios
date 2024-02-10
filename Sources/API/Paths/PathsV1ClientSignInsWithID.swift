//
//  PathsV1ClientSignInsWithID.swift
//  
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get
import URLQueryEncoder

extension ClerkAPI.V1Endpoint.ClientEndpoint.SignInsEndpoint {
    
    func id(_ id: String) -> WithIDEndpoint {
        WithIDEndpoint(path: path + "/\(id)")
    }

    struct WithIDEndpoint {
        /// Path: `/v1/client/sign_ins/{id}`
        let path: String
        
        func get(rotatingTokenNonce: String? = nil) -> Request<ClientResponse<SignIn>> {
            let encoder = URLQueryEncoder()
            encoder.encode(rotatingTokenNonce, forKey: "rotating_token_nonce")
            return .init(path: path, query: encoder.items)
        }
    }
    
}
