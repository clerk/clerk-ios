//
//  PathsV1Organizations.swift
//  Clerk
//
//  Created by Mike Pitre on 2/6/25.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint {
    
    var organizations: OrganizationsEndpoint {
        OrganizationsEndpoint(path: path + "/organizations")
    }
    
    struct OrganizationsEndpoint {
        /// Path: `/v1/organizations`
        let path: String
    }
}
