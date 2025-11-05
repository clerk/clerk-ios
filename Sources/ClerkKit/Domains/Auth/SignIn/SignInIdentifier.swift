//
//  SignInIdentifier.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//

public extension SignIn {
  /// Represents the authentication identifiers supported for signing in.
  ///
  /// The `Identifier` enum defines the types of identifiers that can be used during the sign-in process. Each identifier corresponds to a specific authentication method.
  enum Identifier: String, Codable, Sendable, Equatable, Hashable {
    /// Represents an email address identifier.
    case emailAddress = "email_address"

    /// Represents a phone number identifier.
    case phoneNumber = "phone_number"

    /// Represents a Web3 wallet address identifier).
    case web3Wallet = "web3_wallet"

    /// Represents a username identifier.
    case username

    /// Represents a passkey identifier.
    case passkey

    /// Represents an unsupported or unknown identifier.
    case unknown

    /// Initializes a `SignInIdentifier` from a decoder.
    ///
    /// This initializer attempts to decode a `SignInIdentifier` from the raw value. If the value is not recognized, it defaults to `.unknown`.
    ///
    /// - Parameter decoder: The decoder to use for decoding the raw value.
    /// - Throws: An error if the decoding process fails.
    public init(from decoder: Decoder) throws {
      self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
    }
  }
}
