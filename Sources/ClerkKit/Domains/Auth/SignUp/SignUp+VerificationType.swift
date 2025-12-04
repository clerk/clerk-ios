//
//  SignUp+VerificationType.swift
//  Clerk
//
//  Created by Mike Pitre on 1/30/25.
//

import Foundation

public extension SignUp {
  /// Represents the type of verification method for sign-up.
  enum VerificationType: Sendable {
    /// Email code verification.
    case email

    /// Phone code verification (SMS).
    case phone

    /// Returns the strategy value for the API.
    public var strategy: FactorStrategy {
      switch self {
      case .email:
        .emailCode
      case .phone:
        .phoneCode
      }
    }
  }
}
