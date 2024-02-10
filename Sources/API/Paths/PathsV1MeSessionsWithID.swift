//
//  PathsV1MeSessionsWithID.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation

extension ClerkAPI.V1Endpoint.MeEndpoint.SessionsEndpoint {
    
    func withId(id: String) -> WithIdEndpoint {
        WithIdEndpoint(path: path + "/\(id)")
    }
    
    struct WithIdEndpoint {
        /// Path: `v1/me/sessions/{id}`
        let path: String
    }
    
}
