//
//  SignIn+Status.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//

extension SignIn {
  /// Represents the current status of the sign-in process.
  ///
  /// The `Status` enum defines the possible states of a sign-in flow. Each state indicates a specific requirement or completion level in the sign-in process.
  public enum Status: Codable, Sendable, Equatable, Hashable {
    /// The user is signed in.
    case complete

    /// The user's identifier (e.g., email address, phone number, username) hasn't been provided.
    case needsIdentifier

    /// A first-factor verification strategy is missing.
    case needsFirstFactor

    /// A second-factor verification strategy is missing.
    case needsSecondFactor

    /// The user needs to set a new password.
    case needsNewPassword

    /// Client trust verification is required.
    case needsClientTrust

    /// The sign-in returned an unknown status value.
    ///
    /// The associated value captures the raw string value from the API.
    case unknown(String)

    /// The raw string value used in the API.
    public var rawValue: String {
      switch self {
      case .complete:
        "complete"
      case .needsIdentifier:
        "needs_identifier"
      case .needsFirstFactor:
        "needs_first_factor"
      case .needsSecondFactor:
        "needs_second_factor"
      case .needsNewPassword:
        "needs_new_password"
      case .needsClientTrust:
        "needs_client_trust"
      case .unknown(let value):
        value
      }
    }

    /// Creates a `Status` from its raw string value.
    public init(rawValue: String) {
      switch rawValue {
      case "complete":
        self = .complete
      case "needs_identifier":
        self = .needsIdentifier
      case "needs_first_factor":
        self = .needsFirstFactor
      case "needs_second_factor":
        self = .needsSecondFactor
      case "needs_new_password":
        self = .needsNewPassword
      case "needs_client_trust":
        self = .needsClientTrust
      default:
        self = .unknown(rawValue)
      }
    }

    /// Initializes a `SignInStatus` from a decoder.
    ///
    /// This initializer attempts to decode a `SignInStatus` from the raw value. If the value is not recognized, it defaults to `.unknown(rawValue)`.
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
