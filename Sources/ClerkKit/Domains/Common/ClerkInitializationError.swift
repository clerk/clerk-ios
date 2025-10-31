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
        case .clientLoadFailed(let error),
             .environmentLoadFailed(let error),
             .initializationFailed(let error):
            return error
        default:
            return nil
        }
    }
    
    /// Additional context about the error, such as the invalid key or failure reason.
    public var context: [String: String]? {
        switch self {
        case .invalidPublishableKeyFormat(let key):
            return ["key": key]
        case .apiClientInitializationFailed(let reason):
            return ["reason": reason]
        default:
            return nil
        }
    }
    
    public var errorDescription: String? {
        switch self {
        case .missingPublishableKey:
            return "Clerk publishable key is missing. Please call Clerk.configure(publishableKey:options:) with a valid publishable key before calling load()."
            
        case .invalidPublishableKeyFormat(let key):
            let maskedKey = key.isEmpty ? "empty" : (key.count > 10 ? String(key.prefix(10)) + "..." : key)
            return "Invalid publishable key format: '\(maskedKey)'. Publishable keys must start with 'pk_test_' or 'pk_live_'."
            
        case .clientLoadFailed(let underlyingError):
            return "Failed to load client data: \(underlyingError.localizedDescription)"
            
        case .environmentLoadFailed(let underlyingError):
            return "Failed to load environment configuration: \(underlyingError.localizedDescription)"
            
        case .apiClientInitializationFailed(let reason):
            return "Failed to initialize API client: \(reason)"
            
        case .initializationFailed(let underlyingError):
            return "Failed to initialize Clerk: \(underlyingError.localizedDescription)"
        }
    }
    
    /// A more detailed error message for debugging.
    public var failureReason: String? {
        switch self {
        case .missingPublishableKey:
            return "No publishable key was provided to Clerk.configure()."
            
        case .invalidPublishableKeyFormat(let key):
            return "The provided key '\(key)' does not match the expected format (pk_test_... or pk_live_...)."
            
        case .clientLoadFailed(let underlyingError):
            return "The underlying error was: \(underlyingError)"
            
        case .environmentLoadFailed(let underlyingError):
            return "The underlying error was: \(underlyingError)"
            
        case .apiClientInitializationFailed(let reason):
            return reason
            
        case .initializationFailed(let underlyingError):
            return "An unexpected error occurred during initialization: \(underlyingError)"
        }
    }
}

