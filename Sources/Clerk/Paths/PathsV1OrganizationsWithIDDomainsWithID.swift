//
//  PathsV1OrganizationsWithIDDomainsWithID.swift
//  Clerk
//
//  Created by Mike Pitre on 2/11/25.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.OrganizationsEndpoint.WithIdEndpoint.DomainsEndpoint {
    
    func id(_ id: String) -> WithIdEndpoint {
        WithIdEndpoint(path: path + "/\(id)")
    }
    
    struct WithIdEndpoint {
        /// Path: `/v1/organizations/{id}/domains/{id}`
        let path: String
        
        var get: Request<ClientResponse<OrganizationDomain>> {
            .init(path: path)
        }
    }
    
}
