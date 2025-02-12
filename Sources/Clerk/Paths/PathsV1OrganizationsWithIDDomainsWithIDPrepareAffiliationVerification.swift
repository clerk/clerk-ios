//
//  PathsV1OrganizationsWithIDDomainsWithIDPrepareAffiliationVerification.swift
//  Clerk
//
//  Created by Mike Pitre on 2/12/25.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.OrganizationsEndpoint.WithIdEndpoint.DomainsEndpoint.WithIdEndpoint {
    
    var prepareAffiliationVerification: PrepareAffiliationVerificationEndpoint {
        PrepareAffiliationVerificationEndpoint(path: path + "prepare_affiliation_verification")
    }
    
    struct PrepareAffiliationVerificationEndpoint {
        /// Path: `/v1/organizations/{id}/domains/{id}/prepare_affiliation_verification`
        let path: String
        
        var post: Request<ClientResponse<OrganizationDomain>> {
            .init(path: path)
        }
    }
    
}
