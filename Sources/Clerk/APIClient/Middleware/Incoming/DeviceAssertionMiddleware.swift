//
//  DeviceAssertionMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/30/25.
//

import Foundation
import Get

/// If we recieve a 401 with a clerk error code of "requires_assertion",
/// we need to perform device assertion and then retry the request.
struct DeviceAssertionMiddleware {
    
    static func process(client: APIClient, shouldRetry task: URLSessionTask, error: any Error) async throws -> Bool {
        if let clerkAPIError = error as? ClerkAPIError, clerkAPIError.code == "requires_assertion" {
            try await AppAttestHelper.performAssertion()
            return true
        }
        
        return false
    }
    
}
