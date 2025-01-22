//
//  TransferFlowResult.swift
//  Clerk
//
//  Created by Mike Pitre on 1/6/25.
//

import Foundation

/// Represents the result of an authentication attempt that may have been transferred from sign in to sign up, or vice versa.
///
/// This enum is used to handle scenarios where the authentication flow dynamically determines whether
/// the user should proceed with a sign-in or a sign-up. It accounts for cases where a transfer between
/// the two flows is required, and the result may not always indicate a completed sign-in or sign-up.
/// Additional actions may be needed to finalize the authentication process.
///
/// ### Example
/// ```swift
/// let result = try await SignIn.authenticateWithRedirect(.oauth(provider: .google))
///
/// switch result {
/// case .signIn(let signIn):
///     print("Proceed with sign-in: \(signIn)")
/// case .signUp(let signUp):
///     print("Transferred to sign-up: \(signUp)")
/// }
/// ```
public enum TransferFlowResult {
    /// The authentication flow resulted in a sign-in instance. This case indicates that the user is
    /// being signed in, although further steps may be required to complete the process.
    case signIn(SignIn)
    
    /// The authentication flow resulted in a sign-up instance. This case indicates that the user is
    /// being signed up, although further steps may be required to complete the process.
    case signUp(SignUp)
}


