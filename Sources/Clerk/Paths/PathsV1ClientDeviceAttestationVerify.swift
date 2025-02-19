//
//  PathsV1ClientDeviceAttestationVerify.swift
//  Clerk
//
//  Created by Mike Pitre on 1/29/25.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.ClientEndpoint.DeviceAttestationEndpoint {
    
    var verify: VerifyEndpoint {
        VerifyEndpoint(path: path + "/verify")
    }

    struct VerifyEndpoint {
        /// Path: `v1/client/device_attestation/verify`
        let path: String
        
        func post(_ body: any Encodable) -> Request<Void> {
            .init(path: path, method: .post, body: body)
        }
    }
    
}
