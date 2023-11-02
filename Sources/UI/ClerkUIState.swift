//
//  ClerkUIState.swift
//
//
//  Created by Mike Pitre on 10/25/23.
//

#if canImport(UIKit)

import Foundation

public final class ClerkUIState: ObservableObject {
    
    /// Is the auth view  being displayed.
    @Published public var authIsPresented = false

    public enum AuthStep {        
        case signInStart
        case signInFirstFactor
        case signUpStart
        case signUpVerification
    }
    
    @Published public var presentedAuthStep: AuthStep = .signInStart {
        willSet {
            authIsPresented = true
        }
    }
    
    public enum SignInRoute {
        case start
        case verifyEmailAddress
        case verifyPhone
        case password
    }
    
    public enum SignUpRoute {
        case start
        case verifyEmailAddress
        case verifyPhone
    }
    
}

#endif
