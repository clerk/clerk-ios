//
//  SignInFactorOneView.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

#if canImport(UIKit)

import SwiftUI
import ClerkSDK

struct SignInFactorOneView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.openURL) private var openURL
        
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    private var strategy: Strategy? {
        guard signIn.status == .needsFirstFactor else { return nil }
        if case .signInFactorOne(let factor) = clerkUIState.presentedAuthStep {
            return factor?.verificationStrategy
        }
        return nil
    }
    
    // Note: For some reason, attaching the transition modifier to every view individually works, but attached it once to the Group does not work consistently.
    
    var body: some View {
        Group {
            switch strategy {
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
            case .resetPasswordEmailCode, .resetPasswordPhoneCode:
                SignInFactorOneResetView()
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
                
            case nil:
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
    SignInFactorOneView()
        .environmentObject(Clerk.mock)
        .environmentObject(ClerkUIState())
}

#endif
