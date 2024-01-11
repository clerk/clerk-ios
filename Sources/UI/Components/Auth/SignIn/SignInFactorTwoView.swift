//
//  SignInFactorTwoView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignInFactorTwoView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
        
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    private var strategy: Strategy? {
        guard signIn.status == .needsSecondFactor else { return nil }
        if case .signInFactorTwo(let factor) = clerkUIState.presentedAuthStep {
            return factor?.verificationStrategy
        }
        return nil
    }
    
    // Note: For some reason, attaching the transition modifier to every view individually works, but attached it once to the Group does not work consistently.
    
    var body: some View {
        Group {
            switch strategy {
            case .phoneCode:
                SignInFactorTwoPhoneCodeView()
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .totp:
                SignInFactorTwoTotpCodeView()
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .backupCode:
                SignInFactorTwoBackupCodeView()
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            default:
                ProgressView()
                    .task { clerkUIState.setAuthStepToCurrentStatus(for: signIn) }
            }
        }
        .animation(.snappy, value: strategy)
    }
}

#Preview {
    SignInFactorTwoView()
}

#endif