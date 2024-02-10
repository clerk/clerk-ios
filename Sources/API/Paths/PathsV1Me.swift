//
//  PathsV1Me.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint {
    
    var me: MeEndpoint {
        MeEndpoint(path: path + "/me")
    }
    
    struct MeEndpoint {
        /// Path: `v1/me`
        let path: String
        
        func get() -> Request<ClientResponse<User>> {
            .init(path: path)
        }
        
        func update(_ params: User.UpdateParams) -> Request<ClientResponse<User>> {
            .init(path: path, method: .patch, body: params)
        }
    }
    
}
