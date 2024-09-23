//
//  PathsV1MePasskeys.swift
//  Clerk
//
//  Created by Mike Pitre on 9/6/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.MeEndpoint {
    
    var passkeys: PasskeysEndpoint {
        PasskeysEndpoint(path: path + "/passkeys")
    }
    
    struct PasskeysEndpoint {
        /// Path: `/v1/me/passkeys`
        let path: String
        
        func post(queryItems: [URLQueryItem] = []) -> Request<ClientResponse<Passkey>> {
            .init(path: path, method: .post, query: queryItems.asTuples)
        }
    }
    
}
