//
//  UserUpdatePasswordParams.swift
//  Clerk
//
//  Created by Mike Pitre on 1/24/25.
//

extension User {

  public struct UpdatePasswordParams: Encodable, Sendable {

    public init(
      currentPassword: String? = nil,
      newPassword: String,
      signOutOfOtherSessions: Bool = true
    ) {
      self.currentPassword = currentPassword
      self.newPassword = newPassword
      self.signOutOfOtherSessions = signOutOfOtherSessions
    }

    /// The user's current password.
    public let currentPassword: String?
    /// The user's new password.
    public let newPassword: String
    /// If set to true, all sessions will be signed out.
    public let signOutOfOtherSessions: Bool
  }

}
