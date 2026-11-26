//
//  ClerkDeviceBindingResponseMiddleware.swift
//  Clerk
//

import Foundation

enum DeviceBindingError: String, CaseIterable {
  case proofInvalid = "device_binding_proof_invalid"
  case proofReplayed = "device_binding_proof_replayed"
  case proofMissing = "device_binding_proof_missing"
  case keyMismatch = "device_binding_key_mismatch"

  enum Recovery: Equatable {
    case retryWithServerClock
    case dropToken
    case none
  }

  var recovery: Recovery {
    switch self {
    case .proofInvalid:
      .retryWithServerClock
    case .proofMissing, .keyMismatch:
      .dropToken
    case .proofReplayed:
      .none
    }
  }

  init?(response: HTTPURLResponse, data: Data) {
    guard response.statusCode == 401,
          let errorResponse = try? JSONDecoder.clerkDecoder.decode(ClerkErrorResponse.self, from: data)
    else {
      return nil
    }
    let codes = Set(errorResponse.errors.map(\.code))
    guard let error = Self.allCases.first(where: { codes.contains($0.rawValue) }) else {
      return nil
    }
    self = error
  }
}

struct ClerkDeviceBindingResponseMiddleware: ClerkResponseMiddleware {
  private let runtimeScope: ClerkRuntimeScope

  init(runtimeScope: ClerkRuntimeScope) {
    self.runtimeScope = runtimeScope
  }

  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws {
    guard let error = DeviceBindingError(response: response, data: data),
          error.recovery == .dropToken,
          let deviceToken = request.value(forHTTPHeaderField: "Authorization").nilIfEmpty
    else {
      return
    }
    ClerkLogger.warning("Device binding: dropping the device token after \(error.rawValue)")
    let clerk = try await runtimeScope.withCurrentClerk { $0 }
    _ = try await clerk.identityController.compareAndSetDeviceToken(nil, expected: deviceToken)
  }
}

struct ClerkDpopRetryMiddleware: NetworkRetryMiddleware {
  func shouldRetry(
    request: URLRequest,
    response: HTTPURLResponse?,
    error: any Error,
    attempts: Int
  ) async throws -> Bool {
    guard attempts == 1,
          request.value(forHTTPHeaderField: DpopProof.headerName) != nil,
          let response,
          response.statusCode == 401,
          response.serverDate != nil,
          let apiError = error as? ClerkAPIError,
          apiError.code == DeviceBindingError.proofInvalid.rawValue
    else {
      return false
    }
    ClerkLogger.debug("Retrying with a DPoP proof dated by the server clock")
    return true
  }
}
