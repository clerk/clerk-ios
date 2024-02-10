//
//  PathsV1MeEmailAddresses.swift
//  
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.MeEndpoint {
    
    var emailAddresses: EmailAddressesEndpoint {
        EmailAddressesEndpoint(path: path + "/email_addresses")
    }
    
    struct EmailAddressesEndpoint {
        /// Path: `v1/me/email_addresses`
        let path: String
        
        func post(_ params: EmailAddress.CreateParams) -> Request<ClientResponse<EmailAddress>> {
            .init(path: path, method: .post, body: params)
        }
    }
    
}
