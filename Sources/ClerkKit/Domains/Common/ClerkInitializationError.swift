//
//  ClerkInitializationError.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

/// Errors that can occur during Clerk initialization and configuration.
public enum ClerkInitializationError: Error, LocalizedError, ClerkError {
  /// The publishable key is missing or empty.
  case missingPublishableKey

  /// The publishable key format is invalid.
  ///
  /// - Parameter key: The invalid key that was provided.
  case invalidPublishableKeyFormat(key: String)

  /// Failed to load client data from the API.
  ///
  /// - Parameter underlyingError: The underlying error that caused the failure.
  case clientLoadFailed(underlyingError: Error)

  /// Failed to load environment configuration from the API.
  ///
  /// - Parameter underlyingError: The underlying error that caused the failure.
  case environmentLoadFailed(underlyingError: Error)

  /// Failed to initialize the API client.
  ///
  /// - Parameter reason: A description of why initialization failed.
  case apiClientInitializationFailed(reason: String)

  /// An unexpected error occurred during initialization.
  ///
  /// - Parameter underlyingError: The underlying error that caused the failure.
  case initializationFailed(underlyingError: Error)

  /// A human-readable error message describing what went wrong.
  public var message: String? {
    errorDescription
  }

  /// The underlying error that caused this initialization error, if any.
  public var underlyingError: Error? {
    switch self {
    case let .clientLoadFailed(error),
         let .environmentLoadFailed(error),
         let .initializationFailed(error):
      error
    default:
      nil
    }
  }

  /// Additional context about the error, such as the invalid key or failure reason.
  public var context: [String: String]? {
    switch self {
    case let .invalidPublishableKeyFormat(key):
      ["key": key]
    case let .apiClientInitializationFailed(reason):
      ["reason": reason]
    default:
      nil
    }
  }

  public var errorDescription: String? {
    switch self {
    case .missingPublishableKey:
      return "Clerk publishable key is missing. Please call Clerk.configure(publishableKey:options:) with a valid publishable key before calling load()."

    case let .invalidPublishableKeyFormat(key):
      let maskedKey = key.isEmpty ? "empty" : (key.count > 10 ? String(key.prefix(10)) + "..." : key)
      return "Invalid publishable key format: '\(maskedKey)'. Publishable keys must start with 'pk_test_' or 'pk_live_'."

    case let .clientLoadFailed(underlyingError):
      return "Failed to load client data: \(underlyingError.localizedDescription)"

    case let .environmentLoadFailed(underlyingError):
      return "Failed to load environment configuration: \(underlyingError.localizedDescription)"

    case let .apiClientInitializationFailed(reason):
      return "Failed to initialize API client: \(reason)"

    case let .initializationFailed(underlyingError):
      return "Failed to initialize Clerk: \(underlyingError.localizedDescription)"
    }
  }

  /// A more detailed error message for debugging.
  public var failureReason: String? {
    switch self {
    case .missingPublishableKey:
      "No publishable key was provided to Clerk.configure()."

    case let .invalidPublishableKeyFormat(key):
      "The provided key '\(key)' does not match the expected format (pk_test_... or pk_live_...)."

    case let .clientLoadFailed(underlyingError):
      "The underlying error was: \(underlyingError)"

    case let .environmentLoadFailed(underlyingError):
      "The underlying error was: \(underlyingError)"

    case let .apiClientInitializationFailed(reason):
      reason

    case let .initializationFailed(underlyingError):
      "An unexpected error occurred during initialization: \(underlyingError)"
    }
  }
}
