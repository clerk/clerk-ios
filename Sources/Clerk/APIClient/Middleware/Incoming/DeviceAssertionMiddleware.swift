//
//  DeviceAssertionMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/30/25.
//

import Foundation
import Get

struct DeviceAssertionMiddleware {
    
    static func process(client: APIClient, shouldRetry task: URLSessionTask, error: any Error) async throws -> Bool {
        
        if let clerkAPIError = error as? ClerkAPIError {
            switch clerkAPIError.code {
                
            case "requires_assertion":
                // If we recieve a clerk error code of "requires_assertion",
                // we need to perform device assertion and then retry the request.
                try await AppAttestHelper.performAssertion()
                return true
                
            case "requires_device_attestation":
                // If we recieve a clerk error code of "requires_device_attestation",
                // the attestation is missing from the db, so we should clear any attestation key id that we might have,
                // and get a fresh attestation before asserting. (`performAssertion()` takes care of getting
                // a new attestation first when we dont have a key id).
                // Lastly, retry the request.
                try AppAttestHelper.removeKeyId()
                try await AppAttestHelper.performAssertion()
                return true
                
            default:
                break
            }
        }
        
        return false
    }
    
}
