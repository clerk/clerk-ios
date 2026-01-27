//
//  ClerkError.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Protocol that unifies all Clerk error types for consistent error handling.
public protocol ClerkError: Error {
  /// A human-readable error message.
  var message: String? { get }

  /// The underlying error that caused this error, if any.
  var underlyingError: Error? { get }

  /// Additional context about the error, such as trace ID or request path.
  var context: [String: String]? { get }
}

extension ClerkError {
  /// Default implementation returns nil for underlying error if not provided.
  public var underlyingError: Error? { nil }

  /// Default implementation returns nil for context if not provided.
  public var context: [String: String]? { nil }
}
