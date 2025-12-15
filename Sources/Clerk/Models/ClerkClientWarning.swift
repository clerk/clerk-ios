//
//  ClerkClientWarning.swift
//  Clerk
//
//  Created by Tom Milewski on 12/15/25.
//

import Foundation

/// An object that represents a warning created by Clerk on the client.
/// Unlike `ClerkClientError`, this does not conform to `Error` and is intended for non-error notices.
public struct ClerkClientWarning: Sendable {
    /// A message that describes the warning.
    public let message: String.LocalizationValue?

    public init(message: String.LocalizationValue? = nil) {
        self.message = message
    }
    
    /// Returns the localized description of the warning.
    public var localizedDescription: String {
        guard let message else { return "" }
        return String(localized: message)
    }
}

