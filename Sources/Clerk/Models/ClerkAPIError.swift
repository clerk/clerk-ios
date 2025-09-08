//
//  ClerkAPIError.swift
//  Clerk
//
//  Created by Mike Pitre on 1/24/25.
//

import Foundation

/// An object that represents an error returned by the Clerk API.
public struct ClerkAPIError: Error, LocalizedError, Codable, Equatable, Hashable {
  /// A string code that represents the error, such as `username_exists_code`.
  public let code: String

  /// A message that describes the error.
  public let message: String?

  /// A more detailed message that describes the error.
  public let longMessage: String?

  /// Additional information about the error.
  public let meta: JSON?

  /// A unique identifier for tracing the specific request, useful for debugging.
  public var clerkTraceId: String?
}

public extension ClerkAPIError {
  var errorDescription: String? { longMessage ?? message }
}

/// Represents the body of Clerk API error responses.
///
/// The `ClerkErrorResponse` structure encapsulates multiple API errors that may occur during a request.
/// It also includes a unique trace ID for debugging purposes.
public struct ClerkErrorResponse: Codable, Equatable {
  /// An array of `ClerkAPIError` objects, each describing an individual error.
  public let errors: [ClerkAPIError]

  /// A unique identifier for tracing the specific request, useful for debugging.
  public let clerkTraceId: String?
}

extension ClerkAPIError {
  static var mock: ClerkAPIError {
    .init(
      code: "error",
      message: "An unknown error occurred.",
      longMessage: "An unknown error occurred. Please try again or contact support.",
      meta: nil,
      clerkTraceId: "1"
    )
  }
}
