//
//  Error+Ext.swift
//  Clerk
//
//  Created by Mike Pitre on 9/23/24.
//

import Foundation
import AuthenticationServices

extension Error {
    
    var isCancelledError: Bool {
        if case ASWebAuthenticationSessionError.canceledLogin = self { return true }
        if case ASAuthorizationError.canceled = self { return true }
        return false
    }
    
}
