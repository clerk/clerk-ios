//
//  ClerkUIState.swift
//
//
//  Created by Mike Pitre on 10/25/23.
//

#if canImport(UIKit)

import Foundation
import Clerk

public final class ClerkUIState: ObservableObject {
    
    /// Is the auth view  being displayed.
    @Published public var authIsPresented = false

    public enum AuthStep: Equatable {
        case signInStart
        case signInPassword
        case signInFactorOneVerify
        case signInFactorOneUseAnotherMethod(_ currentStrategy: Strategy)
        case signInFactorTwoVerify
        case signInFactorTwoUseAnotherMethod(_ currentStrategy: Strategy)
        case signInFactorTwoBackupCode
        case signInForgotPassword
        case signInResetPassword
        case signUpStart
        case signUpVerification
    }
    
    @Published public var presentedAuthStep: AuthStep = .signInStart {
        willSet {
            authIsPresented = true
        }
    }
    
    /// Is the user profile view being displayed
    @Published public var userProfileIsPresented = false    
}

#endif
