//
//  PathsV1MeEmailAddressesWithID.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.MeEndpoint.EmailAddressesEndpoint {
    
    func id(_ id: String) -> WithID {
        WithID(path: path + "/\(id)")
    }

    struct WithID {
        /// Path: `/v1/client/email_addresses/{id}`
        let path: String
        
        var get: Request<ClientResponse<EmailAddress>> {
            .init(path: path)
        }
        
        var delete: Request<ClientResponse<Deletion>> {
            .init(path: path, method: .delete)
        }
    }
    
}
