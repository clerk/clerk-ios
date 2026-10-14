//
//  EmailAddressAttemptVerificationParams.swift
//  Clerk
//

import SwiftUI

extension EmailAddress {
  /// Represents the strategy for attempting email address verification.
  ///
  /// Use this enum to specify the method of verification when calling the ``EmailAddress/verifyCode(_:)`` function.
  public enum AttemptStrategy: Sendable {
    /// The strategy for email verification using a one-time code.
    ///
    /// - Parameter code: The one-time code that was sent to the user's email address when calling ``EmailAddress/sendCode()``.
    case emailCode(code: String)

    var requestBody: RequestBody {
      switch self {
      case let .emailCode(code):
        .init(code: code)
      }
    }

    struct RequestBody: Encodable {
      let code: String
    }
  }
}
