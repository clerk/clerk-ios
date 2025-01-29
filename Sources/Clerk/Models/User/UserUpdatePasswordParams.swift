//
//  UserUpdatePasswordParams.swift
//  Clerk
//
//  Created by Mike Pitre on 1/24/25.
//

extension User {
    
    public struct UpdatePasswordParams: Encodable {
        
        public init(
            newPassword: String,
            currentPassword: String,
            signOutOfOtherSessions: Bool
        ) {
            self.newPassword = newPassword
            self.currentPassword = currentPassword
            self.signOutOfOtherSessions = signOutOfOtherSessions
        }
        
        /// The user's new password.
        public let newPassword: String
        /// The user's current password.
        public let currentPassword: String
        /// If set to true, all sessions will be signed out.
        public let signOutOfOtherSessions: Bool
    }
    
}
