//
//  PathsV1OrganizationsWithIDLogo.swift
//  Clerk
//
//  Created by Mike Pitre on 2/7/25.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.OrganizationsEndpoint.WithIdEndpoint {
    
    var logo: LogoEndpoint {
        LogoEndpoint(path: path + "/logo")
    }
    
    struct LogoEndpoint {
        /// Path: `/v1/organizations/{id}/logo`
        let path: String
        
        var post: Request<ClientResponse<Organization>> {
            .init(path: path, method: .post)
        }
        
        var delete: Request<DeletedObject> {
            .init(path: path, method: .delete)
        }
    }
}
