//
//  OIDCPrompt.swift
//  Clerk
//

import Foundation

/// A typed representation of OIDC `prompt` values used in OAuth authorization requests.
///
/// Use multiple values to request combined prompts, for example:
///
/// ```swift
/// let prompts: [OIDCPrompt] = [.login, .consent]
/// ```
public enum OIDCPrompt: Sendable, Hashable, Equatable {
  case none
  case login
  case consent
  case selectAccount

  /// The value that will be sent to the OAuth provider.
  public var value: String {
    switch self {
    case .none:
      "none"
    case .login:
      "login"
    case .consent:
      "consent"
    case .selectAccount:
      "select_account"
    }
  }
}

extension [OIDCPrompt] {
  var serializedPrompt: String? {
    guard !isEmpty else { return nil }
    return Set(self).map(\.value).joined(separator: " ")
  }
}
