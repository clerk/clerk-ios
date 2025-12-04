//
//  SignIn+MfaType.swift
//  Clerk
//
//  Created by Mike Pitre on 1/30/25.
//

import Foundation

public extension SignIn {
  /// Represents the type of MFA (Multi-Factor Authentication) verification method.
  enum MfaType: Sendable {
    /// Phone code verification (SMS).
    case phoneCode

    /// Email code verification.
    case emailCode

    /// TOTP (Time-based One-Time Password) verification.
    case totp

    /// Backup code verification.
    case backupCode

    /// Returns the strategy value for the API.
    public var strategy: FactorStrategy {
      switch self {
      case .phoneCode:
        .phoneCode
      case .emailCode:
        .emailCode
      case .totp:
        .totp
      case .backupCode:
        .backupCode
      }
    }
  }
}
