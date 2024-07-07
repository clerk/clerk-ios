//
//  PathsV1MeChangePassword.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.MeEndpoint {
    
    var changePassword: ChangePasswordEndpoint {
        ChangePasswordEndpoint(path: path + "/change_password")
    }
    
    struct ChangePasswordEndpoint {
        /// Path: `v1/me/change_password`
        let path: String
        
        func post(queryItems: [URLQueryItem] = [], body: any Encodable) -> Request<ClientResponse<User>> {
            .init(path: path, method: .post, query: queryItems.asTuples, body: body)
        }
        
    }
}
