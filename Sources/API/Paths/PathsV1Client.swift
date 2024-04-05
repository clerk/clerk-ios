//
//  PathsV1Client.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint {
    
    var client: ClientEndpoint {
        ClientEndpoint(path: path + "/client")
    }
    
    struct ClientEndpoint {
        /// Path: `/v1/client`
        let path: String
        
        var get: Request<ClientResponse<Client?>> {
            .init(path: path)
        }
        
        var put: Request<ClientResponse<Client>> {
            .init(path: path, method: .put)
        }
        
        var delete: Request<ClientResponse<Client?>> {
            .init(path: path, method: .delete)
        }
    }
}
