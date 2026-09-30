//
//  ClerkInitializationError.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

enum ClerkInitializationError: Error, LocalizedError, ClerkError {
  case missingPublishableKey

  case invalidPublishableKeyFormat(key: String)

  case clientLoadFailed(underlyingError: Error)

  case environmentLoadFailed(underlyingError: Error)

  case apiClientInitializationFailed(reason: String)

  case initializationFailed(underlyingError: Error)

  var message: String? {
    errorDescription
  }

  var underlyingError: Error? {
    switch self {
    case let .clientLoadFailed(error),
         let .environmentLoadFailed(error),
         let .initializationFailed(error):
      error
    default:
      nil
    }
  }

  var context: [String: String]? {
    switch self {
    case let .invalidPublishableKeyFormat(key):
      ["key": key]
    case let .apiClientInitializationFailed(reason):
      ["reason": reason]
    default:
      nil
    }
  }

  var errorDescription: String? {
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

  var failureReason: String? {
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
