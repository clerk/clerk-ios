//
//  SignUpPrepareVerificationParams.swift
//  Clerk
//
//  Created by Mike Pitre on 1/22/25.
//

import Foundation

public extension SignUp {
  /// Defines the strategies for preparing a verification step during the sign-up process.
  enum PrepareStrategy: Sendable {
    /// Send an email with a unique token to input.
    case emailCode

    /// User will receive a one-time authentication code via SMS.
    case phoneCode

    /// Returns the parameters for the verification process based on the chosen strategy.
    var params: PrepareVerificationParams {
      switch self {
      case .emailCode:
        .init(strategy: "email_code")
      case .phoneCode:
        .init(strategy: "phone_code")
      }
    }
  }

  /// Parameters used to prepare the verification process for the sign-up flow.
  struct PrepareVerificationParams: Encodable, Sendable {
    /// The verification strategy to use.
    public let strategy: String
  }
}
