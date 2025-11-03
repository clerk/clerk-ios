//
//  ClerkErrorThrowingResponseMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation

struct ClerkErrorThrowingResponseMiddleware: NetworkResponseMiddleware {
  func validate(_ response: HTTPURLResponse, data: Data, for request: URLRequest) throws {
  guard response.isError else { return }

  if let clerkErrorResponse = try? JSONDecoder.clerkDecoder.decode(ClerkErrorResponse.self, from: data),
    var clerkAPIError = clerkErrorResponse.errors.first {
    clerkAPIError.clerkTraceId = clerkErrorResponse.clerkTraceId
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
