//
//  ClerkClientError.swift
//
//
//  Created by Mike Pitre on 10/2/23.
//

import Foundation
import SwiftUI

/// An object that represents an error created by Clerk on the client.
public struct ClerkClientError: Error, LocalizedError, ClerkError {
  /// A message that describes the error.
  public var messageLocalizationValue: String.LocalizationValue?

  /// Additional context about the error.
  public var context: [String: String]? {
    nil
  }

  /// A human-readable error message.
  public var message: String? {
    guard let messageLocalizationValue else { return nil }
    return String(localized: messageLocalizationValue)
  }

  public init(message: String.LocalizationValue? = nil) {
    messageLocalizationValue = message
  }
}

extension ClerkClientError {
  public var errorDescription: String? {
    message
  }
}
