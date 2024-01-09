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
        case signInFactorOne(_ factor: Factor?)
        case signInFactorOneUseAnotherMethod(_ currentFactor: Factor?)
        case signInFactorTwo(_ factor: Factor?)
        case signInFactorTwoUseAnotherMethod(_ currentFactor: Factor?)
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
