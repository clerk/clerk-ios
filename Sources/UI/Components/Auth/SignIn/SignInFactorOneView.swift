//
//  SignInFactorOneView.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignInFactorOneView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
        
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    // Note: For some reason, attaching the transition modifier to every view individually works, but attached it once to the Group does not work consistently.
    
    var body: some View {
        Group {
            switch signIn.firstFactorStrategy {
            case .password:
                SignInFactorOnePasswordView()
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .emailCode:
                SignInFactorOneEmailCodeView()
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .phoneCode:
                SignInFactorOnePhoneCodeView()
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            default:
                ProgressView()
                    .task {
                        switch signIn.status {
                        case .needsSecondFactor:
                            clerkUIState.presentedAuthStep = .signInFactorTwo
                        default:
                            clerkUIState.authIsPresented = false
                        }
                    }
            }
        }
        .animation(.snappy, value: signIn.firstFactorStrategy)
    }
}

#Preview {
    SignInFactorOneView()
        .environmentObject(Clerk.mock)
        .environmentObject(ClerkUIState())
}

#endif
