//
//  PathsV1MePasskeysWithID.swift
//  Clerk
//
//  Created by Mike Pitre on 9/6/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.MeEndpoint.PasskeysEndpoint {
    
    func id(_ id: String) -> WithIdEndpoint {
        WithIdEndpoint(path: path + "/\(id)")
    }
    
    struct WithIdEndpoint {
        /// Path: `/v1/me/passkeys/{id}`
        let path: String
        
        func patch(queryItems: [URLQueryItem] = [], body: any Encodable) -> Request<ClientResponse<Passkey>> {
            .init(
                path: path,
                method: .patch,
                query: queryItems.asTuples,
                body: body
            )
        }
        
        func delete(queryItems: [URLQueryItem] = []) -> Request<ClientResponse<DeletedObject>> {
            .init(
                path: path,
                method: .delete,
                query: queryItems.asTuples
            )
        }
    }
    
}
