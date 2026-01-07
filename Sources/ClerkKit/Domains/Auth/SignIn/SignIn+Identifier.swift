//
//  SignIn+Identifier.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//

public extension SignIn {
  /// Represents the authentication identifiers supported for signing in.
  ///
  /// The `Identifier` enum defines the types of identifiers that can be used during the sign-in process. Each identifier corresponds to a specific authentication method.
  enum Identifier: Codable, Sendable, Equatable, Hashable {
    /// Represents an email address identifier.
    case emailAddress

    /// Represents a phone number identifier.
    case phoneNumber

    /// Represents a Web3 wallet address identifier).
    case web3Wallet

    /// Represents a username identifier.
    case username

    /// Represents a passkey identifier.
    case passkey

    /// Represents an unsupported or unknown identifier.
    ///
    /// The associated value captures the raw string value from the API.
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
      case .unknown(let value):
        value
      }
    }

    /// Creates an `Identifier` from its raw string value.
    public init(rawValue: String) {
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
      default:
        self = .unknown(rawValue)
      }
    }

    /// Initializes a `SignInIdentifier` from a decoder.
    ///
    /// This initializer attempts to decode a `SignInIdentifier` from the raw value. If the value is not recognized, it defaults to `.unknown(rawValue)`.
    ///
    /// - Parameter decoder: The decoder to use for decoding the raw value.
    /// - Throws: An error if the decoding process fails.
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
