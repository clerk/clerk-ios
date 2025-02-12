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
                try await AppAttestHelper.performAssertion()
                return true
                
            case "requires_device_attestation":
                try await AppAttestHelper.performDeviceAttestation()
                try await AppAttestHelper.performAssertion()
                return true
                
            default:
                break
            }
        }
        
        return false
    }
    
}
