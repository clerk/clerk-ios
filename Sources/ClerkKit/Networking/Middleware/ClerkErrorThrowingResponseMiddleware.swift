//
//  ClerkErrorThrowingResponseMiddleware.swift
//  Clerk
//

import Foundation

extension URLError {
  /// The `userInfo` key for the HTTP status of an error response without a Clerk error body.
  static let clerkStatusCodeKey = "ClerkHTTPStatusCode"
}

struct ClerkErrorThrowingResponseMiddleware: ClerkResponseMiddleware {
  func validate(_ response: HTTPURLResponse, data: Data, for _: URLRequest) async throws {
    guard response.isError else { return }

    if let clerkErrorResponse = try? JSONDecoder.clerkDecoder.decode(ClerkErrorResponse.self, from: data),
       var clerkAPIError = clerkErrorResponse.errors.first
    {
      clerkAPIError.clerkTraceId = clerkErrorResponse.clerkTraceId
      clerkAPIError.statusCode = response.statusCode
      ClerkLogger.logNetworkError(
        clerkAPIError,
        endpoint: response.url?.absoluteString ?? "unknown",
        statusCode: response.statusCode
      )
      throw clerkAPIError
    }

    let error = URLError(.unknown, userInfo: [URLError.clerkStatusCodeKey: response.statusCode])
    ClerkLogger.logNetworkError(
      error,
      endpoint: response.url?.absoluteString ?? "unknown",
      statusCode: response.statusCode
    )
    throw error
  }
}
