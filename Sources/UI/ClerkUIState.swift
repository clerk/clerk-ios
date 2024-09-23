//
//  ClerkUIState.swift
//
//
//  Created by Mike Pitre on 10/25/23.
//

#if os(iOS)

import Foundation

final class ClerkUIState: ObservableObject {
        
    /// Is the auth view  being displayed.
    @Published public var authIsPresented = false

    enum AuthStep: Equatable, Hashable {
        case signInStart
        case signInFactorOne(signIn: SignIn, factor: SignInFactor?)
        case signInFactorOneUseAnotherMethod(signIn: SignIn, currentFactor: SignInFactor?)
        case signInFactorTwo(signIn: SignIn, factor: SignInFactor?)
        case signInFactorTwoUseAnotherMethod(signIn: SignIn, currentFactor: SignInFactor?)
        case signInForgotPassword(signIn: SignIn)
        case signInResetPassword(signIn: SignIn)
        case ssoCallback(signIn: SignIn)
        
        case signUpStart
        case signUpVerification(signUp: SignUp)
        case signUpCreatePasskey(signUp: SignUp, user: User)
    }
    
    @Published var presentedAuthStep: AuthStep = .signInStart {
        willSet {
            authIsPresented = true
        }
    }
    
    /// Is the user profile view being displayed
    @Published var userProfileIsPresented = false
}

extension ClerkUIState {
    
    /// Sets the current auth step to the status determined by the API
    @MainActor
    func setAuthStepToCurrentStatus(for signIn: SignIn) {
        if signIn.firstFactorVerification?.status == .transferable, Clerk.shared.environment?.displayConfig.botProtectionIsEnabled == true {
            presentedAuthStep = .ssoCallback(signIn: signIn)
            return
        }
        
        switch signIn.status {
        case .needsIdentifier, .abandoned:
            presentedAuthStep = .signInStart
            
        case .needsFirstFactor:
            guard let currentFirstFactor = signIn.currentFirstFactor else { authIsPresented = false; return }
            presentedAuthStep = .signInFactorOne(signIn: signIn, factor: currentFirstFactor)
            
        case .needsSecondFactor:
            guard let currentSecondFactor = signIn.currentSecondFactor else { authIsPresented = false; return }
            presentedAuthStep = .signInFactorTwo(signIn: signIn, factor: currentSecondFactor)
            
        case .needsNewPassword:
            presentedAuthStep = .signInResetPassword(signIn: signIn)
            
        case .complete:
            authIsPresented = false
            
        case .unknown:
            authIsPresented = false
        }
    }
    
    /// Sets the current auth step to the status determined by the API
    @MainActor
    func setAuthStepToCurrentStatus(for signUp: SignUp) {
        switch signUp.status {
        case .missingRequirements:
            if (signUp.unverifiedFields ?? []).contains(where: { $0 == "email_address" || $0 == "phone_number" })  {
                presentedAuthStep = .signUpVerification(signUp: signUp)
            } else {
                presentedAuthStep = .signUpStart
            }
            
        case .abandoned:
            presentedAuthStep = .signUpStart
            
        case .complete:
            // if a user just signed up, passkeys are enabled and they dont have any passkeys on their account
            // then ask them if they would like to create one
            if
                Clerk.shared.environment?.userSettings.config(for: "passkey")?.enabled == true,
                let user = Clerk.shared.user,
                user.passkeys.isEmpty
            {
                presentedAuthStep = .signUpCreatePasskey(signUp: signUp, user: user)
                return
            }
            
            authIsPresented = false
            
        case .unknown:
            authIsPresented = false
        }
    }
    
}

#endif
