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

    let nsError = self as NSError
    if nsError.domain == ASAuthorizationError.errorDomain {
      return nsError.code == ASAuthorizationError.Code.canceled.rawValue
    }

    if let biometricCredentialError = self as? BiometricCredentialKeyManagerError,
       biometricCredentialError == .biometricAuthenticationCanceled
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
