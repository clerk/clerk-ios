//
//  ClerkAPIError.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

/// The body of Clerk API Error responses, can contain multiple `ClerkAPIError`.
struct ClerkErrorResponse: Decodable {
    let errors: [ClerkAPIError]
    let clerkTraceId: String
}

/// Custom error return by the Clerk API
struct ClerkAPIError: Error, LocalizedError, Decodable {
    var message: String?
    var longMessage: String?
    
    var errorDescription: String? { longMessage ?? message }
}

/// Custom Clerk error created on the client
struct ClerkClientError: Error, LocalizedError {
    var message: String?
    
    var errorDescription: String? { message }
}
