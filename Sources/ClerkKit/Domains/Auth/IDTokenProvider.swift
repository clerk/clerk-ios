//
//  IDTokenProvider.swift
//
//
//  Created by Mike Pitre on 9/16/24.
//

import Foundation

/// Represents the available identity providers for ID token authentication.
///
/// This enum provides different identity providers that can be used for ID token authentication.
public enum IDTokenProvider: CaseIterable, Codable, Sendable {

  /// The identity provider for Sign in with Apple.
  case apple

  /// Returns the corresponding strategy string for the identity provider.
  ///
  /// This property converts the identity provider into a string that can be used for ID token authentication
  /// or passed as a strategy parameter.
  var strategy: String {
    switch self {
    case .apple:
      return "oauth_token_apple"
    }
  }

  /// Initializes an `IDTokenProvider` instance from a strategy string.
  ///
  /// - Parameter strategy: The strategy string representing the identity provider.
  init?(strategy: String) {
    if let provider = Self.allCases.first(where: { $0.strategy == strategy }) {
      self = provider
    } else {
      return nil
    }
  }
}
