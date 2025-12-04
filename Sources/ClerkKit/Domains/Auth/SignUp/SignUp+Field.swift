//
//  SignUp+Field.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//

import Foundation

public extension SignUp {
  /// Represents a field that can be required, missing, or unverified during sign-up.
  ///
  /// This enum provides type-safe representation of sign-up fields with support for
  /// unknown values to maintain forward compatibility with new fields added by the backend.
  enum Field: Hashable, Codable, Sendable {
    case emailAddress
    case phoneNumber
    case web3Wallet
    case username
    case passkey
    case password
    case authenticatorApp
    case ticket
    case backupCode
    case firstName
    case lastName
    case saml
    case enterpriseSSO
    case legalAccepted
    case customAction
    case oauth(OAuthProvider)
    case unknown(String)

    /// The raw string value used in the API.
    public var rawValue: String {
      switch self {
      case .emailAddress:
        "email_address"
      case .phoneNumber:
        "phone_number"
      case .web3Wallet:
        "web3_wallet"
      case .username:
        "username"
      case .passkey:
        "passkey"
      case .password:
        "password"
      case .authenticatorApp:
        "authenticator_app"
      case .ticket:
        "ticket"
      case .backupCode:
        "backup_code"
      case .firstName:
        "first_name"
      case .lastName:
        "last_name"
      case .saml:
        "saml"
      case .enterpriseSSO:
        "enterprise_sso"
      case .legalAccepted:
        "legal_accepted"
      case .customAction:
        "custom_action"
      case let .oauth(provider):
        provider.strategy
      case .unknown(let value):
        value
      }
    }

    /// Creates a `SignUp.Field` from its raw string value.
    public init(rawValue: String) { // swiftlint:disable:this cyclomatic_complexity
      switch rawValue {
      case "email_address":
        self = .emailAddress
      case "phone_number":
        self = .phoneNumber
      case "web3_wallet":
        self = .web3Wallet
      case "username":
        self = .username
      case "passkey":
        self = .passkey
      case "password":
        self = .password
      case "authenticator_app":
        self = .authenticatorApp
      case "ticket":
        self = .ticket
      case "backup_code":
        self = .backupCode
      case "first_name":
        self = .firstName
      case "last_name":
        self = .lastName
      case "saml":
        self = .saml
      case "enterprise_sso":
        self = .enterpriseSSO
      case "legal_accepted":
        self = .legalAccepted
      case "custom_action":
        self = .customAction
      default:
        if rawValue.hasPrefix("oauth_") {
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
}
