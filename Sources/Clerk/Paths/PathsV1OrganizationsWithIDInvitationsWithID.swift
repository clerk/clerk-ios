//
//  PathsV1OrganizationsWithIDInvitationsWithID.swift
//  Clerk
//
//  Created by Mike Pitre on 2/12/25.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.OrganizationsEndpoint.WithIdEndpoint.InvitationsEndpoint {
    
    func id(_ id: String) -> WithIdEndpoint {
        WithIdEndpoint(path: path + "/\(id)")
    }
    
    struct WithIdEndpoint {
        /// Path: `/v1/organizations/{id}/invitations/{id}`
        let path: String
    }
    
}
