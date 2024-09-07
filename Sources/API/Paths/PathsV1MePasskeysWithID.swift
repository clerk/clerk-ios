//
//  PathsV1MePasskeysWithID.swift
//  Clerk
//
//  Created by Mike Pitre on 9/6/24.
//

import Foundation

extension ClerkAPI.V1Endpoint.MeEndpoint.PasskeysEndpoint {
    
    func withId(_ id: String) -> WithIdEndpoint {
        WithIdEndpoint(path: path + "/\(id)")
    }
    
    struct WithIdEndpoint {
        /// Path: `/v1/me/passkeys/{id}`
        let path: String
    }
    
}
