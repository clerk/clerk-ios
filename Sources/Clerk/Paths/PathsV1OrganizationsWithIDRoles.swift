//
//  PathsV1OrganizationsWithIDRoles.swift
//  Clerk
//
//  Created by Mike Pitre on 2/7/25.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.OrganizationsEndpoint.WithIdEndpoint {
    
    var roles: RolesEndpoint {
        RolesEndpoint(path: path + "/roles")
    }
    
    struct RolesEndpoint {
        /// Path: `/v1/organizations/{id}/roles`
        let path: String
        
        func get(queryItems: [URLQueryItem] = []) -> Request<ClientResponse<Organization>> {
            .init(path: path, method: .post, query: queryItems.asTuples)
        }
    }
}
