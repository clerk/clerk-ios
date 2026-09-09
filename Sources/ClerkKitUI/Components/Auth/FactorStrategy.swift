//
//  FactorStrategy.swift
//  Clerk
//

import ClerkKit
import Foundation

/// Represents a factor verification strategy used in the sign-in process.
///
/// This enum provides type-safe representation of factor strategies with support for
/// OAuth providers, ID token providers, and unknown values to maintain forward compatibility with new strategies.
enum FactorStrategy: Hashable {
  // Standard strategies
  case password
  case emailCode
  case emailLink
  case phoneCode
  case passkey
  case biometricCredential
  case totp
  case backupCode
  case ticket

  // Reset password strategies
  case resetPasswordEmailCode
  case resetPasswordPhoneCode

  // Enterprise strategies
  case saml
  case enterpriseSSO

  /// OAuth strategies (uses OAuthProvider enum)
  case oauth(OAuthProvider)

  /// ID token strategies (uses IDTokenProvider enum)
  case idToken(String)

  /// Unknown for forward compatibility
  case unknown(String)

  /// The raw string value used in the API.
  var rawValue: String {
    switch self {
    case .password:
      "password"
    case .emailCode:
      "email_code"
    case .emailLink:
      "email_link"
    case .phoneCode:
      "phone_code"
    case .passkey:
      "passkey"
    case .biometricCredential:
      "trusted_device"
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
      provider
    case let .unknown(value):
      value
    }
  }

  /// Creates a `FactorStrategy` from its raw string value.
  init(rawValue: String) { // swiftlint:disable:this cyclomatic_complexity
    switch rawValue {
    case "password":
      self = .password
    case "email_code":
      self = .emailCode
    case "email_link":
      self = .emailLink
    case "phone_code":
      self = .phoneCode
    case "passkey":
      self = .passkey
    case "trusted_device":
      self = .biometricCredential
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
        self = .idToken(rawValue)
      } else if rawValue.hasPrefix("oauth_") {
        self = .oauth(OAuthProvider(strategy: rawValue))
      } else {
        self = .unknown(rawValue)
      }
    }
  }
}

// MARK: - Strategy Groups

extension FactorStrategy {
  var canAttemptFirstFactorCode: Bool {
    switch self {
    case .emailCode, .phoneCode, .resetPasswordEmailCode, .resetPasswordPhoneCode:
      true
    default:
      false
    }
  }

  /// Strategies that use email as the identifier
  static let emailStrategies: [FactorStrategy] = [
    .emailCode,
    .emailLink,
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
