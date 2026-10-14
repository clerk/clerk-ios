//
//  EmailAddressPrepareVerificationParams.swift
//  Clerk
//

extension EmailAddress {
  /// Represents the strategy for preparing the verification process for an email address.
  ///
  /// Use this enum to specify how the verification email will be sent to the user.
  public enum PrepareStrategy: Sendable {
    /// User will receive a one-time authentication code via email.
    case emailCode

    var requestBody: RequestBody {
      switch self {
      case .emailCode:
        .init(strategy: "email_code")
      }
    }

    struct RequestBody: Encodable {
      let strategy: String
    }
  }
}
