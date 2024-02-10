//
//  PathsV1MePhoneNumbersWithID.swift
//  
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.MeEndpoint.PhoneNumbersEndpoint {
    
    func id(_ id: String) -> WithID {
        WithID(path: path + "/\(id)")
    }

    struct WithID {
        /// Path: `/v1/me/phone_numbers/{id}`
        let path: String
        
        var get: Request<ClientResponse<PhoneNumber>> {
            .init(path: path)
        }
        
        func patch(body: Encodable) -> Request<ClientResponse<PhoneNumber>> {
            .init(path: path, method: .patch, body: body)
        }
        
        var delete: Request<Void> {
            .init(path: path, method: .delete)
        }
    }
    
}
