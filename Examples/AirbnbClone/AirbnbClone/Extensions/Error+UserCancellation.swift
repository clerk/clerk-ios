//
//  Error+UserCancellation.swift
//  AirbnbClone
//

import AuthenticationServices
import ClerkKit
import Foundation

extension Error {
  /// Returns true when the user (or the system) cancelled an auth flow and we should not surface an error UI.
  var isUserCancellation: Bool {
    if let error = self as? CoreError, ["user_cancelled", "cancelled"].contains(error.code) { return true }
    if case ASWebAuthenticationSessionError.canceledLogin = self { return true }

    if let authError = self as? ASAuthorizationError,
       authError.errorUserInfo["NSLocalizedFailureReason"] == nil
    {
      return true
    }

    if self is CancellationError { return true }

    return false
  }
}
