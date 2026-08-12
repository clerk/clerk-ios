//
//  ClerkErrorThrowingResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkErrorThrowingResponseMiddleware: ClerkResponseMiddleware {
  private let runtimeScope: ClerkRuntimeScope
  private let logNetworkError: @Sendable (any Error, String, Int?) -> Void

  init(
    runtimeScope: ClerkRuntimeScope,
    logNetworkError: @escaping @Sendable (any Error, String, Int?) -> Void = { error, endpoint, statusCode in
      ClerkLogger.logNetworkError(error, endpoint: endpoint, statusCode: statusCode)
    }
  ) {
    self.runtimeScope = runtimeScope
    self.logNetworkError = logNetworkError
  }

  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) async throws {
    guard response.isError else {
      if response.isSuccess, !isEnvironmentRequest(request) {
        try await runtimeScope.withCurrentClerk {
          $0.applySuccessfulProtectedResponse(requestSequence: request.clerkRequestSequence)
        }
      }
      return
    }

    if let clerkErrorResponse = try? JSONDecoder.clerkDecoder.decode(ClerkErrorResponse.self, from: data),
       var clerkAPIError = clerkErrorResponse.errors.first
    {
      clerkAPIError.clerkTraceId = clerkErrorResponse.clerkTraceId
      if clerkAPIError.isUnsupportedAppVersion {
        try await runtimeScope.withCurrentClerk {
          $0.applyUnsupportedAppVersionMeta(
            clerkAPIError.meta,
            requestSequence: request.clerkRequestSequence
          )
        }
      }
      logNetworkError(
        clerkAPIError,
        response.url?.absoluteString ?? "unknown",
        response.statusCode
      )
      throw clerkAPIError
    }

    let error = URLError(.unknown)
    logNetworkError(
      error,
      response.url?.absoluteString ?? "unknown",
      response.statusCode
    )
    throw error
  }

  private func isEnvironmentRequest(_ request: URLRequest) -> Bool {
    request.url?.path.hasSuffix("/v1/environment") == true
  }
}
