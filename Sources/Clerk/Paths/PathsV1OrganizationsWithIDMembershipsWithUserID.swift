//
//  PathsV1OrganizationsWithIDMembershipsWithUserID.swift
//  Clerk
//
//  Created by Mike Pitre on 2/12/25.
//


import Foundation
import Get

extension ClerkFAPI.V1Endpoint.OrganizationsEndpoint.WithIdEndpoint.MembershipsEndpoint {
    
    func userId(_ id: String) -> WithUserIdEndpoint {
        WithUserIdEndpoint(path: path + "/\(id)")
    }
    
    struct WithUserIdEndpoint {
        /// Path: `/v1/organizations/{id}/memberships/{user_id}`
        let path: String
        
        var patch: Request<ClientResponse<OrganizationMembership>> {
            .init(path: path, method: .patch)
        }
        
        var delete: Request<ClientResponse<OrganizationMembership>> {
            .init(path: path, method: .delete)
        }
    }
    
}
