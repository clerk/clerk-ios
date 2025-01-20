//
//  PathsV1MeSessionsWithIDRevoke.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.MeEndpoint.SessionsEndpoint.WithIdEndpoint {
    
    var revoke: RevokeEndpoint {
        RevokeEndpoint(path: path + "/revoke")
    }
    
    struct RevokeEndpoint {
        /// Path: `v1/me/sessions/{id}/revoke`
        let path: String
        
        func post(queryItems: [URLQueryItem] = []) -> Request<ClientResponse<Session>> {
            .init(path: path, method: .post, query: queryItems.asTuples)
        }
        
    }
    
}
