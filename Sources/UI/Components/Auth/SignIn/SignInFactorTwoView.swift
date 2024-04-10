//
//  SignInFactorTwoView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if canImport(SwiftUI)

import SwiftUI

struct SignInFactorTwoView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.openURL) private var openURL
        
    private var signIn: SignIn? {
        clerk.client?.signIn
    }
    
    private var strategy: Strategy? {
        guard signIn?.status == .needsSecondFactor else { return nil }
        if case .signInFactorTwo(let factor) = clerkUIState.presentedAuthStep {
            return factor?.strategyEnum
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
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .totp:
                SignInFactorTwoTotpCodeView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .backupCode:
                SignInFactorTwoBackupCodeView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
                
            case nil where clerk.session == nil:
                GetHelpView(
                    title: "Cannot sign in",
                    description: """
                    
                    Cannot proceed with sign in. There's no available authentication factor.
                    
                    If you’re experiencing difficulty signing into your account, email us and we will work with you to restore access as soon as possible.
                    """,
                    primaryButtonConfig: .init(label: "Email support", action: {
                        openURL(URL(string: "mailto:")!)
                    }),
                    secondaryButtonConfig: .init(label: "Back to sign in", action: {
                        clerkUIState.presentedAuthStep = .signInStart
                    })
                )
                .task { clerkUIState.setAuthStepToCurrentStatus(for: signIn) }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
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
