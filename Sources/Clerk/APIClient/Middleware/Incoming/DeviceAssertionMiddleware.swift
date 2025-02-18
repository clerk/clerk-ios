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
    
    static func process(task: URLSessionTask, error: any Error) async throws -> Bool {
        return try await manager.performDeviceAssertion(task: task, error: error)
    }
    
    private actor Manager {
        private var inFlightTask: Task<Bool, Error>?
        private var inFlightErrorCode: String?

        func performDeviceAssertion(task: URLSessionTask, error: any Error) async throws -> Bool {
            guard
                let clerkAPIError = error as? ClerkAPIError,
                ["requires_assertion", "requires_device_attestation"].contains(clerkAPIError.code)
            else {
                return false
            }
            
            // If there's already an ongoing task, decide if this error should wait or override
            // "requires_device_attestation" should override "requires_assertion"
            // therefore it breaks and creates a new task, not awaiting the inflight task
            if let inFlightTask, let inFlightErrorCode {
                switch (inFlightErrorCode, clerkAPIError.code) {
                case ("requires_assertion", "requires_device_attestation"):
                    break
                default:
                    return try await inFlightTask.value
                }
            }
            
            // Create a new task for the current error code
            let newTask = Task<Bool, Error> {
                defer {
                    inFlightTask = nil
                    inFlightErrorCode = nil
                }
                
                switch clerkAPIError.code {
                case "requires_assertion":
                    try await AppAttestHelper.performAssertion()
                    return true
                    
                case "requires_device_attestation":
                    try await AppAttestHelper.performDeviceAttestation()
                    try await AppAttestHelper.performAssertion()
                    
                    // if the original request was a client/verify, we dont need to retry it.
                    // The above perform assertion uses the new attestation to verify.
                    if let url = task.originalRequest?.url, url.path().hasSuffix("client/verify") {
                        return false
                    }
                    
                    return true
                    
                default:
                    return false
                }
            }
            
            inFlightTask = newTask
            inFlightErrorCode = clerkAPIError.code
            
            return try await newTask.value
        }
    }
}
