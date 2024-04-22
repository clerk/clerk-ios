//
//  PathsV1ClientSignUpsWithID.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.ClientEndpoint.SignUpsEndpoint {
    func id(_ id: String) -> WithID {
        WithID(path: path + "/\(id)")
    }

    struct WithID {
        /// Path: `/v1/client/sign_ups/{id}`
        let path: String
        
        func get(rotatingTokenNonce: String? = nil) -> Request<ClientResponse<SignUp>> {
            if let rotatingTokenNonce {
                let queryEncodedNonce = rotatingTokenNonce.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
                return .init(path: path, query: [("rotating_token_nonce", queryEncodedNonce)])
            } else {
                return .init(path: path)
            }
        }
        
        func patch(_ params: SignUp.UpdateParams) -> Request<ClientResponse<SignUp>> {
            .init(path: path, method: .patch, body: params)
        }
    }
}
