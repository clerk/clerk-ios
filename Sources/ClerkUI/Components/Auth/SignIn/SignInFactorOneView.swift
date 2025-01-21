//
//  SignInFactorOneView.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

#if os(iOS)

import SwiftUI
import Clerk

struct SignInFactorOneView: View {
    var clerk = Clerk.shared
    @Environment(ClerkUIState.self) private var clerkUIState
    @Environment(\.openURL) private var openURL
        
    let factor: SignInFactor
    
    private var signIn: SignIn? {
        clerk.client?.signIn
    }
        
    // Note: For some reason, attaching the transition modifier to every view individually works, but attached it once to the Group does not work consistently.
    
    var body: some View {
        Group {
            switch factor.strategy {
            case "password":
                SignInFactorOnePasswordView(factor: factor)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case "email_code":
                SignInFactorOneEmailCodeView(factor: factor)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case "phone_code":
                SignInFactorOnePhoneCodeView(factor: factor)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case "reset_password_email_code":
                SignInFactorOneResetView(factor: factor)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
                
            default:
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
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity.animation(nil)
                ))
            }
        }
        .animation(.snappy, value: factor)
    }
}

#Preview {
    SignInFactorOneView(factor: .mock)
        .environment(AuthView.Config())
        .environment(ClerkUIState())
        .environment(ClerkTheme.clerkDefault)
}

#endif
