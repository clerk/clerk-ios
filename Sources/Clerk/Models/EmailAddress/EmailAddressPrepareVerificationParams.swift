//
//  EmailAddressPrepareVerificationParams.swift
//  Clerk
//
//  Created by Mike Pitre on 1/24/25.
//

public extension EmailAddress {
  /// Represents the strategy for preparing the verification process for an email address.
  ///
  /// Use this enum to specify how the verification email will be sent to the user.
  enum PrepareStrategy: Sendable {
    /// User will receive a one-time authentication code via email.
    case emailCode

    /// Converts the strategy into the required request body for the verification process.
    var requestBody: RequestBody {
      switch self {
      case .emailCode:
        .init(strategy: "email_code")
      }
    }

    /// Represents the body of the request used to prepare the email address verification.
    struct RequestBody: Encodable {
      /// The verification strategy.
      let strategy: String
    }
  }
}
