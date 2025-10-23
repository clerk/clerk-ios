//
//  ClerkClientError.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import SwiftUI

/// An object that represents an error created by Clerk on the client.
public struct ClerkClientError: Error, LocalizedError {
    /// A message that describes the error.
    public let message: String.LocalizationValue?

    public init(message: String.LocalizationValue? = nil) {
        self.message = message
    }
}

extension ClerkClientError {
    public var errorDescription: String? {
        guard let message else { return nil }
        return String(localized: message)
    }
}

extension ClerkClientError {

    static var mock: ClerkClientError {
        .init(message: "An unknown error occurred.")
    }

}
