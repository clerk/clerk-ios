//
//  PathsV1ClientSignUpsWithID.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get
import URLQueryEncoder

extension ClerkAPI.V1Endpoint.ClientEndpoint.SignUpsEndpoint {
    func id(_ id: String) -> WithID {
        WithID(path: path + "/\(id)")
    }

    struct WithID {
        /// Path: `/v1/client/sign_ups/{id}`
        let path: String
        
        func get(rotatingTokenNonce: String? = nil) -> Request<ClientResponse<SignUp>> {
            let encoder = URLQueryEncoder()
            encoder.encode(rotatingTokenNonce, forKey: "rotating_token_nonce")
            return .init(path: path, query: encoder.items)
        }
    }
}
