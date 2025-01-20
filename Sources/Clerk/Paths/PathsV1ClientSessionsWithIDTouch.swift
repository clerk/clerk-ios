//
//  PathsV1ClientSessionsWithIDTouch.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.ClientEndpoint.SessionsEndpoint.WithIdEndpoint {
    
    var touch: TouchEndpoint {
        TouchEndpoint(path: path + "/touch")
    }
    
    struct TouchEndpoint {
        /// Path: `v1/client/sessions/{id}/touch`
        let path: String
        
        var post: Request<ClientResponse<Session>> {
            .init(path: path, method: .post)
        }
    }
    
}
