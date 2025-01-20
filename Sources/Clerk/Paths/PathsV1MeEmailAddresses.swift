//
//  PathsV1MeEmailAddresses.swift
//  
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.MeEndpoint {
    
    var emailAddresses: EmailAddressesEndpoint {
        EmailAddressesEndpoint(path: path + "/email_addresses")
    }
    
    struct EmailAddressesEndpoint {
        /// Path: `v1/me/email_addresses`
        let path: String
        
        func post(queryItems: [URLQueryItem] = [], body: any Encodable) -> Request<ClientResponse<EmailAddress>> {
            .init(path: path, method: .post, query: queryItems.asTuples, body: body)
        }
    }
    
}
