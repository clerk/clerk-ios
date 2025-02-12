//
//  DeviceAssertionMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/30/25.
//

import Foundation
import Get

struct DeviceAssertionMiddleware {
    private static let manager = Manager()
    
    static func process(error: any Error) async throws -> Bool {
        return try await manager.performDeviceAssertion(error: error)
    }
    
    private actor Manager {
        private var ongoingTask: Task<Bool, Error>?

        func performDeviceAssertion(error: any Error) async throws -> Bool {
            if let ongoingTask {
                return try await ongoingTask.value
            } else {
                let newTask = Task<Bool, Error> {
                    defer { ongoingTask = nil }
                    
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

                ongoingTask = newTask

                return try await newTask.value
            }
        }
    }
    
}
