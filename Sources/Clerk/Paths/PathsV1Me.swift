//
//  PathsV1Me.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint {
    
    var me: MeEndpoint {
        MeEndpoint(path: path + "/me")
    }
    
    struct MeEndpoint {
        /// Path: `v1/me`
        let path: String
        
        func get() -> Request<ClientResponse<User>> {
            .init(path: path)
        }
        
        func update(queryItems: [URLQueryItem] = [], body: any Encodable) -> Request<ClientResponse<User>> {
            .init(path: path, method: .patch, query: queryItems.asTuples, body: body)
        }
        
        func delete(queryItems: [URLQueryItem] = []) -> Request<ClientResponse<DeletedObject>> {
            .init(path: path, method: .delete, query: queryItems.asTuples)
        }
    }
    
}
