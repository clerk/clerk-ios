//
//  PathsV1MePhoneNumbers.swift
//
//
//  Created by Mike Pitre on 2/10/24.
//

import Foundation
import Get

extension ClerkAPI.V1Endpoint.MeEndpoint {
    
    var phoneNumbers: PhoneNumbersEndpoint {
        PhoneNumbersEndpoint(path: path + "/phone_numbers")
    }
    
    struct PhoneNumbersEndpoint {
        /// Path: `v1/me/phone_numbers`
        let path: String
        
        func post(_ params: User.CreatePhoneNumberParams) -> Request<ClientResponse<PhoneNumber>> {
            .init(path: path, method: .post, body: params)
        }
    }
    
}
