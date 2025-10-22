//
//  ClerkDeviceAssertionRetrier.swift
//  Clerk
//
//  Created by Mike Pitre on 1/30/25.
//

import Foundation

struct ClerkDeviceAssertionRetrier: RequestRetrier {
        
    static func shouldRetry(task: URLSessionTask, error: any Error, attempts: Int) async throws -> Bool {
        guard let clerkAPIError = error as? ClerkAPIError, clerkAPIError.code == "requires_assertion" else {
            return false
        }
        
        try await AssertionManager.shared.performDeviceAssertion()
        return true
    }
    
}

private actor AssertionManager {
    static let shared = AssertionManager()
    
    private var inFlightTask: Task<Void, Error>?

    func performDeviceAssertion() async throws {
        if let inFlightTask {
            return try await inFlightTask.value
        }

        let newTask = Task<Void, Error> {
            defer {
                inFlightTask = nil
            }

            do {
                try await AppAttestHelper.performAssertion()
            } catch let error as ClerkAPIError where error.code == "requires_device_attestation" {
                try await AppAttestHelper.performDeviceAttestation()
                try await AppAttestHelper.performAssertion()
            }
        }

        inFlightTask = newTask

        try await newTask.value
    }
}
