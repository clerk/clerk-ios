//
//  PathsV1OrganizationsWithIDMembershipRequests.swift
//  Clerk
//
//  Created by Mike Pitre on 2/11/25.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.OrganizationsEndpoint.WithIdEndpoint {
    
    var membershipRequests: MembershipRequestsEndpoint {
        MembershipRequestsEndpoint(path: path + "/membership_requests")
    }
    
    struct MembershipRequestsEndpoint {
        /// Path: `/v1/organizations/{id}/membership_requests`
        let path: String
        
        var get: Request<ClientResponse<ClerkPaginatedResponse<OrganizationMembershipRequest>>> {
            .init(path: path)
        }
    }
}
