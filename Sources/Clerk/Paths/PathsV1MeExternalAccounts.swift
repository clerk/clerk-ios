//
//  PathsV1MeExternalAccounts.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.MeEndpoint {
    
    var externalAccounts: ExternalAccountsEndpoint {
        ExternalAccountsEndpoint(path: path + "/external_accounts")
    }
    
    struct ExternalAccountsEndpoint {
        /// Path: `v1/me/external_accounts`
        let path: String
        
        func create(queryItems: [URLQueryItem] = [], body: any Encodable) -> Request<ClientResponse<ExternalAccount>> {
            .init(path: path, method: .post, query: queryItems.asTuples, body: body)
        }
    }
    
}
