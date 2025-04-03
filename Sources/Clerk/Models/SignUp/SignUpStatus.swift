//
//  SignUpStatus.swift
//  Clerk
//
//  Created by Mike Pitre on 1/22/25.
//

extension SignUp {

  /// Represents the current status of the sign-up process.
  ///
  /// The `Status` enum defines the possible states of a sign-up flow. Each state indicates a specific requirement or completion level in the sign-up process.
  public enum Status: String, Codable, Sendable, Equatable {
    /// The sign-up has been inactive for over 24 hours.
    case abandoned

    /// A requirement is unverified or missing from the Email, Phone, Username settings. For example, in the Clerk Dashboard, the Password setting is required but a password wasn't provided in the custom flow.
    case missingRequirements = "missing_requirements"

    /// All the required fields have been supplied and verified, so the sign-up is complete and a new user and a session have been created.
    case complete

    /// The status is unknown.
    case unknown

    public init(from decoder: Decoder) throws {
      self = try .init(rawValue: decoder.singleValueContainer().decode(RawValue.self)) ?? .unknown
    }
  }

}
