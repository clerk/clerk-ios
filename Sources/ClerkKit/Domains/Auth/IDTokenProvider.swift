//
//  IDTokenProvider.swift
//

import Foundation

/// Represents the available identity providers for ID token authentication.
///
/// This enum provides different identity providers that can be used for ID token authentication.
public enum IDTokenProvider: CaseIterable, Codable, Sendable {
  /// The identity provider for Sign in with Apple.
  case apple

  var strategy: String {
    switch self {
    case .apple:
      "oauth_token_apple"
    }
  }

  init?(strategy: String) {
    if let provider = Self.allCases.first(where: { $0.strategy == strategy }) {
      self = provider
    } else {
      return nil
    }
  }
}
