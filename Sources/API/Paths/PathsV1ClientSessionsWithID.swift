//
//  PathsV1ClientSessionsWithID.swift
//  
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation

extension ClerkAPI.V1Endpoint.ClientEndpoint.SessionsEndpoint {
    
    func id(_ id: String) -> WithIdEndpoint {
        WithIdEndpoint(path: path + "/\(id)")
    }
    
    struct WithIdEndpoint {
        /// Path: `v1/client/sessions/{id}`
        let path: String
    }
    
}
