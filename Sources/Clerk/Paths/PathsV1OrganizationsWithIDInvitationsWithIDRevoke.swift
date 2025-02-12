//
//  PathsV1OrganizationsWithIDInvitationsWithIDRevoke.swift
//  Clerk
//
//  Created by Mike Pitre on 2/12/25.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.OrganizationsEndpoint.WithIdEndpoint.InvitationsEndpoint.WithIdEndpoint {
    
    var revoke: RevokeEndpoint {
        RevokeEndpoint(path: path + "revoke")
    }
    
    struct RevokeEndpoint {
        /// Path: `/v1/organizations/{id}/invitations/{id}/revoke`
        let path: String
        
        var post: Request<ClientResponse<OrganizationInvitation>> {
            .init(path: path)
        }
    }
    
}
