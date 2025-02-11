//
//  PathsV1OrganizationsWithIDDomains.swift
//  Clerk
//
//  Created by Mike Pitre on 2/11/25.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.OrganizationsEndpoint.WithIdEndpoint {
    
    var domains: DomainsEndpoint {
        DomainsEndpoint(path: path + "/domains")
    }
    
    struct DomainsEndpoint {
        /// Path: `/v1/organizations/{id}/domains`
        let path: String
        
        var get: Request<ClientResponse<ClerkPaginatedResponse<OrganizationDomain>>> {
            .init(path: path)
        }
        
        var post: Request<ClientResponse<OrganizationDomain>> {
            .init(path: path, method: .post)
        }
    }
    
}
