//
//  PathsV1OrganizationsWithIDInvitations.swift
//  Clerk
//
//  Created by Mike Pitre on 2/11/25.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.OrganizationsEndpoint.WithIdEndpoint {
    
    var invitations: InvitationsEndpoint {
        InvitationsEndpoint(path: path + "/invitations")
    }
    
    struct InvitationsEndpoint {
        /// Path: `/v1/organizations/{id}/invitations`
        let path: String
        
        var get: Request<ClientResponse<ClerkPaginatedResponse<OrganizationInvitation>>> {
            .init(path: path)
        }
        
        var post: Request<ClientResponse<OrganizationInvitation>> {
            .init(path: path, method: .post)
        }
    }
}
