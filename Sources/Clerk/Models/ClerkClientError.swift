//
//  ClerkClientError.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation

/// An interface that represents an error created by Clerk on the client.
public struct ClerkClientError: Error, LocalizedError {
    /// A message that describes the error.
    public let message: String?
    
    public init(message: String? = nil) {
        self.message = message
    }
}
    
extension ClerkClientError {
    public var errorDescription: String? { message }
}
