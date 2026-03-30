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
  func validatedPrompt() throws -> String? {
    guard !isEmpty else { return nil }
    let unique = Set(self)
    if unique.count != count {
      throw ClerkClientError(
        message: "Duplicate OIDC prompt values are not allowed."
      )
    }
    if unique.contains(.none), unique.count > 1 {
      throw ClerkClientError(
        message: "The OIDC prompt value \"none\" cannot be combined with other prompt values."
      )
    }
    return map(\.value).joined(separator: " ")
  }
}
