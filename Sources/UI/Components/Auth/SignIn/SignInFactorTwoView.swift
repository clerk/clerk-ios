//
//  SignInFactorTwoView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if os(iOS)

import SwiftUI

struct SignInFactorTwoView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.openURL) private var openURL
        
    let signIn: SignIn
    let factor: SignInFactor?
    
    // Note: For some reason, attaching the transition modifier to every view individually works, but attached it once to the Group does not work consistently.
    
    var body: some View {
        Group {
            switch factor?.strategyEnum {
            case .phoneCode:
                SignInFactorTwoPhoneCodeView(signIn: signIn)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .totp:
                SignInFactorTwoTotpCodeView(signIn: signIn)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .backupCode:
                SignInFactorTwoBackupCodeView(signIn: signIn)
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
        .animation(.snappy, value: factor?.strategyEnum)
    }
}

#Preview {
    SignInFactorTwoView(signIn: .mock, factor: .mock)
}

#endif
