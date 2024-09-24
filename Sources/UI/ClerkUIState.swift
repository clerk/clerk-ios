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
        case signInFactorOne(factor: SignInFactor)
        case signInFactorOneUseAnotherMethod(currentFactor: SignInFactor)
        case signInFactorTwo(factor: SignInFactor)
        case signInFactorTwoUseAnotherMethod(currentFactor: SignInFactor)
        case signInForgotPassword(factor: SignInFactor)
        case signInResetPassword
        case ssoCallback
        
        case signUpStart
        case signUpVerification
        case signUpCreatePasskey
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
    func setAuthStepToCurrentSignInStatus() {
        let signIn = Clerk.shared.client?.signIn
        
        if signIn?.firstFactorVerification?.status == .transferable,
           Clerk.shared.environment?.displayConfig.botProtectionIsEnabled == true
        {
            presentedAuthStep = .ssoCallback
            return
        }
        
        switch signIn?.status {
            
        case .needsIdentifier:
            presentedAuthStep = .signInStart
            
        case .needsFirstFactor:
            guard let currentFirstFactor = signIn?.currentFirstFactor else { presentedAuthStep = .signInStart; return }
            presentedAuthStep = .signInFactorOne(factor: currentFirstFactor)
            
        case .needsSecondFactor:
            guard let currentSecondFactor = signIn?.currentSecondFactor else { presentedAuthStep = .signInStart; return }
            presentedAuthStep = .signInFactorTwo(factor: currentSecondFactor)
            
        case .needsNewPassword:
            presentedAuthStep = .signInResetPassword
            
        case .complete, .none:
            authIsPresented = false
            
        case .abandoned:
            presentedAuthStep = .signInStart
            
        case .unknown:
            authIsPresented = false
        }
    }
    
    /// Sets the current auth step to the status determined by the API
    @MainActor
    func setAuthStepToCurrentSignUpStatus() {
        let signUp = Clerk.shared.client?.signUp
        
        switch signUp?.status {
            
        case .missingRequirements:
            if (signUp?.unverifiedFields ?? []).contains(where: { $0 == "email_address" || $0 == "phone_number" })  {
                presentedAuthStep = .signUpVerification
            } else {
                presentedAuthStep = .signUpStart
            }
            
        case .abandoned:
            presentedAuthStep = .signUpStart
            
        case .complete, .none:
            
            // if a user just signed up, passkeys are enabled and they dont have any passkeys on their account
            // then ask them if they would like to create one
            if Clerk.shared.environment?.userSettings.config(for: "passkey")?.enabled == true,
               let user = Clerk.shared.user,
               user.passkeys.isEmpty
            {
                presentedAuthStep = .signUpCreatePasskey
                return
            }
            
            authIsPresented = false
            
        case .unknown:
            authIsPresented = false
        }
    }
}

#endif
