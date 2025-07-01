//
//  ErrorThrowingMiddleware.swift
//  Clerk
//
//  Created by Mike Pitre on 1/8/25.
//

import Foundation
import Get

struct ErrorThrowingMiddleware {

  static func process(_ response: HTTPURLResponse, data: Data) throws {

    // If our response is an error status code...
    guard (200..<300).contains(response.statusCode) else {

      // ...and the response has a ClerkError body throw a custom clerk error
      if let clerkErrorResponse = try? JSONDecoder.clerkDecoder.decode(ClerkErrorResponse.self, from: data),
        var clerkAPIError = clerkErrorResponse.errors.first
      {
        clerkAPIError.clerkTraceId = clerkErrorResponse.clerkTraceId
        ClerkLogger.logNetworkError(
          clerkAPIError,
          endpoint: response.url?.absoluteString ?? "unknown",
          statusCode: response.statusCode
        )
        throw clerkAPIError
      }

      // ...else throw a generic api error
      let apiError = APIError.unacceptableStatusCode(response.statusCode)
      ClerkLogger.logNetworkError(
        apiError,
        endpoint: response.url?.absoluteString ?? "unknown",
        statusCode: response.statusCode
      )
      throw apiError
    }

  }

}
