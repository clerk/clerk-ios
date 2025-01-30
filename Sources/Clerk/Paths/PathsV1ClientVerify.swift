//
//  PathsV1ClientVerify.swift
//  Clerk
//
//  Created by Mike Pitre on 1/30/25.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.ClientEndpoint {
 
    var verify: VerifyEndpoint {
        VerifyEndpoint(path: path + "/verify")
    }

    struct VerifyEndpoint {
        /// Path: `v1/client/verify`
        let path: String
        
        func post(_ body: any Encodable) -> Request<Client> {
            .init(path: path, method: .post, body: body)
        }
    }
    
}
