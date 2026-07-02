//
//  Error+Ext.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import AuthenticationServices
import ClerkKit
import Foundation

extension Error {
  var isUserCancelledError: Bool {
    if case ASWebAuthenticationSessionError.canceledLogin = self { return true }

    if let authError = self as? ASAuthorizationError, authError.errorUserInfo["NSLocalizedFailureReason"] == nil {
      return true
    }

    if let trustedDeviceError = self as? TrustedDeviceKeyManagerError,
       trustedDeviceError == .biometricAuthenticationCanceled
    {
      return true
    }

    return false
  }

  var isCancellationError: Bool {
    if self is CancellationError {
      return true
    }

    if let nsError = self as NSError?, nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
      return true
    }

    return false
  }
}

#endif
