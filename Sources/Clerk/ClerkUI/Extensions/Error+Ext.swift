//
//  Error+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 4/23/25.
//

#if os(iOS)

  import AuthenticationServices
  import Foundation

  extension Error {

    var isUserCancelledError: Bool {
      if case ASWebAuthenticationSessionError.canceledLogin = self { return true }

      if let authError = self as? ASAuthorizationError, authError.errorUserInfo["NSLocalizedFailureReason"] == nil {
        return true
      }

      return false
    }

    var isCancellationError: Bool {
      if self is CancellationError {
        return true
      }

      if let nsError = self as NSError?, nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
        return true
      }
      
      return false
    }

  }

#endif
