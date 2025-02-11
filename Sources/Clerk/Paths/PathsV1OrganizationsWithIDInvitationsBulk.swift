//
//  InvitationsEndpoint.swift
//  Clerk
//
//  Created by Mike Pitre on 2/11/25.
//


import Foundation
import Get

extension ClerkFAPI.V1Endpoint.OrganizationsEndpoint.WithIdEndpoint.InvitationsEndpoint {
    
    var bulk: BulkEndpoint {
        BulkEndpoint(path: path + "/bulk")
    }
    
    struct BulkEndpoint {
        /// Path: `/v1/organizations/{id}/invitations/bulk`
        let path: String
        
        var post: Request<ClientResponse<[OrganizationInvitation]>> {
            .init(path: path, method: .post)
        }
    }
}
