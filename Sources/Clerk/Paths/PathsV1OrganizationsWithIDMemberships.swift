//
//  PathsV1OrganizationsWithIDMemberships.swift
//  Clerk
//
//  Created by Mike Pitre on 2/10/25.
//

import Foundation

import Get

extension ClerkFAPI.V1Endpoint.OrganizationsEndpoint.WithIdEndpoint {
    
    var memberships: MembershipsEndpoint {
        MembershipsEndpoint(path: path + "/memberships")
    }
    
    struct MembershipsEndpoint {
        /// Path: `/v1/organizations/{id}/memberships`
        let path: String
        
        var get: Request<ClientResponse<ClerkPaginatedResponse<OrganizationMembership>>> {
            .init(path: path)
        }
        
        var post: Request<ClientResponse<OrganizationMembership>> {
            .init(path: path, method: .post)
        }
        
        var patch: Request<ClientResponse<OrganizationMembership>> {
            .init(path: path, method: .patch)
        }
        
        var delete: Request<ClientResponse<OrganizationMembership>> {
            .init(path: path, method: .delete)
        }
    }
}
