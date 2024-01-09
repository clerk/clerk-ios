//
//  SignInFactorTwoVerificationView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignInFactorTwoVerificationView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
        
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    // Note: For some reason, attaching the transition modifier to every view individually works, but attached it once to the Group does not work consistently.
    
    var body: some View {
        Group {
            switch signIn.secondFactorVerification?.verificationStrategy {
            case .phoneCode:
                SignInFactorTwoPhoneCodeView()
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .totp:
                Text("TOTP")
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            default:
                ProgressView()
                    .task {
                        switch signIn.status {
                        case .needsFirstFactor:
                            clerkUIState.presentedAuthStep = .signInFactorOneVerify
                        case .needsSecondFactor:
                            clerkUIState.presentedAuthStep = .signInFactorTwoVerify
                        case .needsNewPassword:
                            clerkUIState.presentedAuthStep = .signInResetPassword
                        default:
                            clerkUIState.authIsPresented = false
                        }
                    }
            }
        }
        .animation(.snappy, value: signIn.secondFactorVerification?.verificationStrategy)
    }
}

#Preview {
    SignInFactorTwoVerificationView()
}

#endif
