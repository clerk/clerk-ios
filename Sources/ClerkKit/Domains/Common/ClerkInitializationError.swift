//
//  ClerkInitializationError.swift
//  Clerk
//
//  Created on 2025-01-27.
//

import Foundation

enum ClerkInitializationError: Error, LocalizedError, ClerkError {
  case missingPublishableKey

  case invalidPublishableKeyFormat

  case invalidProxyUrl

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
    case let .apiClientInitializationFailed(reason):
      ["reason": reason]
    default:
      nil
    }
  }

  var errorDescription: String? {
    switch self {
    case .missingPublishableKey:
      "Clerk publishable key is missing. Run `npx clerk@latest init` from your Xcode project directory to configure Clerk, or pass a valid publishable key to `Clerk.configure(publishableKey:options:)`."

    case .invalidPublishableKeyFormat:
      "Clerk publishable key is invalid. Verify that the value passed to `Clerk.configure(publishableKey:options:)` is a valid `pk_test_...` or `pk_live_...` key, or run `npx clerk@latest init` from your Xcode project directory to configure Clerk again."

    case .invalidProxyUrl:
      "Invalid proxy URL. The proxy URL must be a full http or https URL, such as https://proxy.example.com/__clerk."

    case let .clientLoadFailed(underlyingError):
      "Failed to load client data: \(underlyingError.localizedDescription)"

    case let .environmentLoadFailed(underlyingError):
      "Failed to load environment configuration: \(underlyingError.localizedDescription)"

    case let .apiClientInitializationFailed(reason):
      "Failed to initialize API client: \(reason)"

    case let .initializationFailed(underlyingError):
      "Failed to initialize Clerk: \(underlyingError.localizedDescription)"
    }
  }

  var failureReason: String? {
    switch self {
    case .missingPublishableKey:
      "No publishable key was provided to Clerk.configure()."

    case .invalidPublishableKeyFormat:
      "The provided publishable key does not match the expected format (pk_test_... or pk_live_...)."

    case .invalidProxyUrl:
      "Clerk.Options.proxyUrl has no http or https scheme or no host, so requests can't be sent through it."

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
