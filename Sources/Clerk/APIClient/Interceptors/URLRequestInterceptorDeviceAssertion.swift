//
//  DeviceAssertionMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/30/25.
//

import Foundation
import RequestBuilder

final class URLRequestInterceptorDeviceAssertion: URLRequestInterceptor, @unchecked Sendable {

  private static let assertionManager = AssertionManager()
  var parent: URLSessionManager!

  func data(for request: URLRequest) async throws -> (Data?, HTTPURLResponse?) {
    let (data, response) = try await parent.data(for: request)

    if let response,
      response.isError,
      let data,
      let clerkErrorResponse = try? JSONDecoder.clerkDecoder.decode(ClerkErrorResponse.self, from: data),
      let clerkAPIError = clerkErrorResponse.errors.first,
      clerkAPIError.code == "requires_assertion"
    {
      do {
        try await Self.assertionManager.performDeviceAssertion(request: request, error: clerkAPIError)
      } catch {
        ClerkLogger.logError(error, message: "Device assertion interceptor failed for request: \(request)")
        return (data, response)
      }

      // retry
      return try await parent.data(for: request)
    }

    // fallback
    return (data, response)
  }

  private actor AssertionManager {
    private var inFlightTask: Task<Void, Error>?

    func performDeviceAssertion(request: URLRequest, error: any Error) async throws {
      if let inFlightTask {
        try await inFlightTask.value
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

}
