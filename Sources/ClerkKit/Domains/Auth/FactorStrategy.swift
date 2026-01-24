//
//  FactorStrategy.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//

import Foundation

/// Represents a factor verification strategy used in the sign-in process.
///
/// This enum provides type-safe representation of factor strategies with support for
/// OAuth providers, ID token providers, and unknown values to maintain forward compatibility with new strategies.
public enum FactorStrategy: Hashable, Codable, Sendable {
  // Standard strategies
  case password
  case emailCode
  case phoneCode
  case passkey
  case totp
  case backupCode
  case ticket

  // Reset password strategies
  case resetPasswordEmailCode
  case resetPasswordPhoneCode

  // Enterprise strategies
  case saml
  case enterpriseSSO

  // OAuth strategies (uses OAuthProvider enum)
  case oauth(OAuthProvider)

  // ID token strategies (uses IDTokenProvider enum)
  case idToken(IDTokenProvider)

  // Unknown for forward compatibility
  case unknown(String)

  /// The raw string value used in the API.
  public var rawValue: String {
    switch self {
    case .password:
      "password"
    case .emailCode:
      "email_code"
    case .phoneCode:
      "phone_code"
    case .passkey:
      "passkey"
    case .totp:
      "totp"
    case .backupCode:
      "backup_code"
    case .ticket:
      "ticket"
    case .resetPasswordEmailCode:
      "reset_password_email_code"
    case .resetPasswordPhoneCode:
      "reset_password_phone_code"
    case .saml:
      "saml"
    case .enterpriseSSO:
      "enterprise_sso"
    case let .oauth(provider):
      provider.strategy
    case let .idToken(provider):
      provider.strategy
    case let .unknown(value):
      value
    }
  }

  /// Creates a `FactorStrategy` from its raw string value.
  public init(rawValue: String) { // swiftlint:disable:this cyclomatic_complexity
    switch rawValue {
    case "password":
      self = .password
    case "email_code":
      self = .emailCode
    case "phone_code":
      self = .phoneCode
    case "passkey":
      self = .passkey
    case "totp":
      self = .totp
    case "backup_code":
      self = .backupCode
    case "ticket":
      self = .ticket
    case "reset_password_email_code":
      self = .resetPasswordEmailCode
    case "reset_password_phone_code":
      self = .resetPasswordPhoneCode
    case "saml":
      self = .saml
    case "enterprise_sso":
      self = .enterpriseSSO
    default:
      if rawValue.hasPrefix("oauth_token_") {
        if let provider = IDTokenProvider(strategy: rawValue) {
          self = .idToken(provider)
        } else {
          self = .unknown(rawValue)
        }
      } else if rawValue.hasPrefix("oauth_") {
        self = .oauth(OAuthProvider(strategy: rawValue))
      } else {
        self = .unknown(rawValue)
      }
    }
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    let rawValue = try container.decode(String.self)
    self.init(rawValue: rawValue)
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(rawValue)
  }
}

// MARK: - Strategy Groups

package extension FactorStrategy {
  /// Strategies that use email as the identifier
  static let emailStrategies: [FactorStrategy] = [
    .emailCode,
    .password,
    .resetPasswordEmailCode,
  ]

  /// Strategies that use phone number as the identifier
  static let phoneStrategies: [FactorStrategy] = [
    .phoneCode,
    .password,
    .resetPasswordPhoneCode,
  ]

  /// Strategies that use username as the identifier
  static let usernameStrategies: [FactorStrategy] = [
    .password,
  ]
}
