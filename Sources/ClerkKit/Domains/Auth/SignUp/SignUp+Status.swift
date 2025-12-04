//
//  SignUpStatus.swift
//  Clerk
//
//  Created by Mike Pitre on 1/22/25.
//

public extension SignUp {
  /// Represents the current status of the sign-up process.
  ///
  /// The `Status` enum defines the possible states of a sign-up flow. Each state indicates a specific requirement or completion level in the sign-up process.
  enum Status: Codable, Sendable, Equatable, Hashable {
    /// The sign-up has been inactive for over 24 hours.
    case abandoned

    /// A requirement is unverified or missing from the Email, Phone, Username settings. For example, in the Clerk Dashboard, the Password setting is required but a password wasn't provided in the custom flow.
    case missingRequirements

    /// All the required fields have been supplied and verified, so the sign-up is complete and a new user and a session have been created.
    case complete

    /// The status is unknown.
    ///
    /// The associated value captures the raw string value from the API.
    case unknown(String)

    /// The raw string value used in the API.
    public var rawValue: String {
      switch self {
      case .abandoned:
        "abandoned"
      case .missingRequirements:
        "missing_requirements"
      case .complete:
        "complete"
      case .unknown(let value):
        value
      }
    }

    /// Creates a `Status` from its raw string value.
    public init(rawValue: String) {
      switch rawValue {
      case "abandoned":
        self = .abandoned
      case "missing_requirements":
        self = .missingRequirements
      case "complete":
        self = .complete
      default:
        self = .unknown(rawValue)
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
