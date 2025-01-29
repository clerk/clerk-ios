//
//  PathsV1ClientDeviceAttestation.swift
//  Clerk
//
//  Created by Mike Pitre on 1/29/25.
//

import Foundation
import Get

extension ClerkFAPI.V1Endpoint.ClientEndpoint {
 
    var deviceAttestation: DeviceAttestationEndpoint {
        DeviceAttestationEndpoint(path: path + "/device_attestation")
    }

    struct DeviceAttestationEndpoint {
        /// Path: `v1/client/device_attestation`
        let path: String
    }
    
}
