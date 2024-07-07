//
//  PathsV1MeExternalAccountsWithID.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.MeEndpoint.ExternalAccountsEndpoint {
    
    func id(_ id: String) -> WithID {
        WithID(path: path + "/\(id)")
    }

    struct WithID {
        /// Path: `/v1/me/external_accounts/{id}`
        let path: String
        
        var get: Request<ClientResponse<ExternalAccount>> {
            return .init(path: path)
        }
        
        func delete(queryItems: [URLQueryItem] = []) -> Request<ClientResponse<Deletion>> {
            .init(path: path, method: .delete, query: queryItems.asTuples)
        }
    }
    
}
