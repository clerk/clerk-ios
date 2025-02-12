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
        private var ongoingErrorCode: String?

        func performDeviceAssertion(error: any Error) async throws -> Bool {
            guard
                let clerkAPIError = error as? ClerkAPIError,
                clerkAPIError.code == "requires_assertion" || clerkAPIError.code == "requires_device_attestation"
            else {
                return false
            }
                        
            // If there's already an ongoing task, decide if this error should wait or override
            if let ongoingTask, let ongoingErrorCode {
                switch (ongoingErrorCode, clerkAPIError.code) {
                case ("requires_device_attestation", "requires_assertion"):
                    // "requires_assertion" should wait for "requires_device_attestation"
                    return try await ongoingTask.value
                case ("requires_assertion", "requires_device_attestation"):
                    // "requires_device_attestation" should override "requires_assertion"
                    break
                default:
                    // Other cases wait for the ongoing task.
                    return try await ongoingTask.value
                }
            }
            
            // Create a new task for the current error code
            let newTask = Task<Bool, Error> {
                defer {
                    ongoingTask = nil
                    ongoingErrorCode = nil
                }
                
                switch clerkAPIError.code {
                case "requires_assertion":
                    try await AppAttestHelper.performAssertion()
                    return true
                    
                case "requires_device_attestation":
                    try await AppAttestHelper.performDeviceAttestation()
                    try await AppAttestHelper.performAssertion()
                    return true
                    
                default:
                    return false
                }
            }
            
            ongoingTask = newTask
            ongoingErrorCode = clerkAPIError.code
            
            return try await newTask.value
        }
    }
}
