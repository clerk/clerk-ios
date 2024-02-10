//
//  PathsV1MeSessionsActive.swift
//  
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.MeEndpoint.SessionsEndpoint {
    
    var active: ActiveEndpoint {
        ActiveEndpoint(path: path + "/active")
    }
    
    struct ActiveEndpoint {
        /// Path: `/v1/me/sessions/active`
        let path: String
        
        var get: Request<[Session]> {
            .init(path: path)
        }
    }
    
}
