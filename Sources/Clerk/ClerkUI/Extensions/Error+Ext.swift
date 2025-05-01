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

  var isCancelledError: Bool {
    if case ASWebAuthenticationSessionError.canceledLogin = self { return true }
    if case ASAuthorizationError.canceled = self { return true }
    return false
  }

}

#endif
