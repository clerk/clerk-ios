//
//  SignInResetPassword.swift
//  Clerk
//
//  Created by Mike Pitre on 1/21/25.
//

import Foundation

extension SignIn {

  /// A parameter object for resetting a user's password.
  ///
  /// - Parameters:
  ///   - password: The user's current password.
  ///   - signOutOfOtherSessions: If true, log the user out of all other authenticated sessions.
  public struct ResetPasswordParams: Encodable, Sendable {

    /// Creates a new `ResetPasswordParams` object.
    ///
    /// - Parameters:
    ///   - password: The user's current password.
    ///   - signOutOfOtherSessions: If true, log the user out of all other authenticated sessions.
    public init(password: String, signOutOfOtherSessions: Bool? = nil) {
      self.password = password
      self.signOutOfOtherSessions = signOutOfOtherSessions
    }

    /// The user's current password.
    public let password: String

    /// If true, log the user out of all other authenticated sessions.
    public let signOutOfOtherSessions: Bool?
  }

}
