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
        case signInCreate
        case signInFirstFactor
        case signUpCreate
        case signUpVerification
    }
    
    @Published public var presentedAuthStep: AuthStep = .signInCreate {
        willSet {
            authIsPresented = true
        }
    }
    
}

#endif
