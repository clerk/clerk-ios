//
//  ClerkError.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

/// The body of Clerk API Error responses, can contain multiple `ClerkAPIError`.
struct ClerkErrorResponse: Codable, Equatable {
    let errors: [ClerkAPIError]
    let clerkTraceId: String
}

/// Custom error returned by the Clerk API.
public struct ClerkAPIError: Error, LocalizedError, Codable, Equatable, Hashable {
    public let code: String
    public let message: String?
    public let longMessage: String?
    public let meta: JSON?
    
    public var errorDescription: String? { longMessage ?? message }
}

/// Custom Clerk error created on the client.
public struct ClerkClientError: Error, LocalizedError {
    init(message: String? = nil) {
        self.message = message
    }
    
    let message: String?
    
    public var errorDescription: String? { message }
}
