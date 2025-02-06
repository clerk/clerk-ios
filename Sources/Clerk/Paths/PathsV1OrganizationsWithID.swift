//
//  PathsV1OrganizationsWithID.swift
//  Clerk
//
//  Created by Mike Pitre on 2/6/25.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.OrganizationsEndpoint {
    
    func id(_ id: String) -> WithIdEndpoint {
        WithIdEndpoint(path: path + "/\(id)")
    }
    
    struct WithIdEndpoint {
        /// Path: `/v1/organizations/{id}`
        let path: String
        
        func patch(queryItems: [URLQueryItem] = [], body: any Encodable) -> Request<ClientResponse<Organization>> {
            .init(path: path, method: .patch, query: queryItems.asTuples, body: body)
        }
        
        func delete(queryItems: [URLQueryItem] = []) -> Request<DeletedObject> {
            .init(path: path, method: .delete, query: queryItems.asTuples)
        }
    }
}
