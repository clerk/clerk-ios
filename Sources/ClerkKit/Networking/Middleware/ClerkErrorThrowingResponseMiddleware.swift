//
//  ClerkErrorThrowingResponseMiddleware.swift
//  Clerk
//

import Foundation

struct ClerkErrorThrowingResponseMiddleware: ClerkResponseMiddleware {
  func validate(_ response: HTTPURLResponse, data: Data, for _: URLRequest) throws {
    guard response.isError else { return }

    if let clerkErrorResponse = try? JSONDecoder.clerkDecoder.decode(ClerkErrorResponse.self, from: data),
       var clerkAPIError = clerkErrorResponse.errors.first
    {
      clerkAPIError.clerkTraceId = clerkErrorResponse.clerkTraceId

      if clerkAPIError.code == "unsupported_app_version" {
        Task { @MainActor in
          Clerk.shared.applyUnsupportedAppVersionMeta(clerkAPIError.meta)
        }
      }

      ClerkLogger.logNetworkError(
        clerkAPIError,
        endpoint: response.url?.absoluteString ?? "unknown",
        statusCode: response.statusCode
      )
      throw clerkAPIError
    }

    let error = URLError(.unknown)
    ClerkLogger.logNetworkError(
      error,
      endpoint: response.url?.absoluteString ?? "unknown",
      statusCode: response.statusCode
    )
    throw error
  }
}
