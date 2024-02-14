//
//  PathsV1MeExternalAccounts.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.MeEndpoint {
    
    var externalAccounts: ExternalAccountsEndpoint {
        ExternalAccountsEndpoint(path: path + "/external_accounts")
    }
    
    struct ExternalAccountsEndpoint {
        /// Path: `v1/me/external_accounts`
        let path: String
        
        func create(_ params: User.CreateExternalAccountParams) -> Request<ClientResponse<ExternalAccount>> {
            .init(path: path, method: .post, body: params)
        }
    }
    
}
