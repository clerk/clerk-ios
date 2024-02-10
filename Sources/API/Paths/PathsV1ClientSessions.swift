//
//  PathsV1ClientSessions.swift
//  
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation

extension ClerkAPI.V1Endpoint.ClientEndpoint {
    
    var sessions: SessionsEndpoint {
        SessionsEndpoint(path: path + "/sessions")
    }
    
    struct SessionsEndpoint {
        /// Path: `v1/client/sessions`
        let path: String
    }
    
}
