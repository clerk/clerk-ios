//
//  PathsV1MeTOTP.swift
//
//
//  Created by Mike Pitre on 2/13/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.MeEndpoint {
    
    var totp: TOTPEndpoint {
        TOTPEndpoint(path: path + "/totp")
    }
    
    struct TOTPEndpoint {
        /// Path: `v1/me/totp`
        let path: String
        
        var post: Request<ClientResponse<TOTPResource>> {
            .init(path: path, method: .post)
        }
        
        var delete: Request<ClientResponse<Deletion>> {
            .init(path: path, method: .delete)
        }
    }
    
}
