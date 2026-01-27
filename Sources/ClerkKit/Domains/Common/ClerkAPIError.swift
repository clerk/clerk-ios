//
//  ClerkAPIError.swift
//  Clerk
//
//  Created by Mike Pitre on 1/24/25.
//

import Foundation

/// An object that represents an error returned by the Clerk API.
public struct ClerkAPIError: Error, LocalizedError, Codable, Equatable, Hashable, ClerkError {
  /// A string code that represents the error, such as `username_exists_code`.
  public var code: String

  /// A message that describes the error.
  public var message: String?

  /// A more detailed message that describes the error.
  public var longMessage: String?

  /// Additional information about the error.
  public var meta: JSON?

  /// A unique identifier for tracing the specific request, useful for debugging.
  public var clerkTraceId: String?

  /// Additional context about the error, including trace ID and parameter name if available.
  public var context: [String: String]? {
    var ctx: [String: String] = [:]
    if let clerkTraceId {
      ctx["traceId"] = clerkTraceId
    }
    if let paramName = meta?["param_name"]?.stringValue {
      ctx["paramName"] = paramName
    }
    return ctx.isEmpty ? nil : ctx
  }
}

extension ClerkAPIError {
  public var errorDescription: String? { longMessage ?? message }
}

/// Represents the body of Clerk API error responses.
///
/// The `ClerkErrorResponse` structure encapsulates multiple API errors that may occur during a request.
/// It also includes a unique trace ID for debugging purposes.
public struct ClerkErrorResponse: Codable, Equatable {
  /// An array of `ClerkAPIError` objects, each describing an individual error.
  public var errors: [ClerkAPIError]

  /// A unique identifier for tracing the specific request, useful for debugging.
  public var clerkTraceId: String?
}
