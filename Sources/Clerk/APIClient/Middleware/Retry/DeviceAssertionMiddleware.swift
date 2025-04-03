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

    func performDeviceAssertion(task: URLSessionTask, error: any Error) async throws -> Bool {
      guard let clerkAPIError = error as? ClerkAPIError, clerkAPIError.code == "requires_assertion" else {
        return false
      }

      if let inFlightTask {
        return try await inFlightTask.value
      }

      let newTask = Task<Bool, Error> {
        defer {
          inFlightTask = nil
        }

        switch clerkAPIError.code {
        case "requires_assertion":
          do {
            return try await handleRequiresAssertionError()
          } catch let error as ClerkAPIError where error.code == "requires_device_attestation" {
            return try await handleRequiresDeviceAttestationError(task: task)
          } catch {
            throw error
          }

        default:
          return false
        }
      }

      inFlightTask = newTask

      return try await newTask.value
    }

    private func handleRequiresAssertionError() async throws -> Bool {
      try await AppAttestHelper.performAssertion()
      return true
    }

    private func handleRequiresDeviceAttestationError(task: URLSessionTask) async throws -> Bool {
      try await AppAttestHelper.performDeviceAttestation()
      try await AppAttestHelper.performAssertion()

      // if the original request was a client/verify, we dont need to retry it.
      // The above `performAssertion()` uses the new attestation to verify.
      if let url = task.originalRequest?.url, url.path().hasSuffix("client/verify") {
        return false
      }

      return true
    }
  }
}
