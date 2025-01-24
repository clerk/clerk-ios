//
//  ClerkAPIError.swift
//  Clerk
//
//  Created by Mike Pitre on 1/24/25.
//

import Foundation

/// An interface that represents an error returned by the Clerk API.
public struct ClerkAPIError: Error, LocalizedError, Codable, Equatable, Hashable {
    /// A string code that represents the error, such as `username_exists_code`.
    public let code: String
    
    /// A message that describes the error.
    public let message: String?
    
    /// A more detailed message that describes the error.
    public let longMessage: String?
    
    /// Additional information about the error.
    public let meta: JSON?
    
}

extension ClerkAPIError {
    public var errorDescription: String? { longMessage ?? message }
}

/// The body of Clerk API Error responses, can contain multiple `ClerkAPIError`.
public struct ClerkErrorResponse: Codable, Equatable {
    public let errors: [ClerkAPIError]
    public let clerkTraceId: String
}
