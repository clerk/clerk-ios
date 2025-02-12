//
//  PathsV1OrganizationsWithIDDomainsWithIDAttemptAffiliationVerification.swift.swift
//  Clerk
//
//  Created by Mike Pitre on 2/12/25.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.OrganizationsEndpoint.WithIdEndpoint.DomainsEndpoint.WithIdEndpoint {
    
    var attemptAffiliationVerification: AttemptAffiliationVerificationEndpoint {
        AttemptAffiliationVerificationEndpoint(path: path + "attempt_affiliation_verification")
    }
    
    struct AttemptAffiliationVerificationEndpoint {
        /// Path: `/v1/organizations/{id}/domains/{id}/attempt_affiliation_verification`
        let path: String
        
        var post: Request<ClientResponse<OrganizationDomain>> {
            .init(path: path)
        }
    }
    
}
