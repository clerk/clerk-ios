//
//  PathsV1MeExternalAccountsWithID.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.MeEndpoint.ExternalAccountsEndpoint {
    
    func id(_ id: String) -> WithIdEndpoint {
        WithIdEndpoint(path: path + "/\(id)")
    }

    struct WithIdEndpoint {
        /// Path: `/v1/me/external_accounts/{id}`
        let path: String
        
        var get: Request<ClientResponse<ExternalAccount>> {
            return .init(path: path)
        }
        
        func delete(queryItems: [URLQueryItem] = []) -> Request<ClientResponse<DeletedObject>> {
            .init(path: path, method: .delete, query: queryItems.asTuples)
        }
    }
    
}
