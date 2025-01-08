//
//  SignUpVerificationView.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

#if os(iOS)

import SwiftUI
import Factory

struct SignUpVerificationView: View {
    var clerk = Clerk.shared
    @Environment(ClerkUIState.self) private var clerkUIState
    @Environment(\.openURL) private var openURL
    @State private var errorWrapper: ErrorWrapper?
        
    private var signUp: SignUp? {
        clerk.client?.signUp
    }
    
    var body: some View {
        Group {
            switch signUp?.nextStrategyToVerify {
            case .phoneCode:
                SignUpPhoneCodeView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
                
            case .emailCode:
                SignUpEmailCodeView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
                
            case .none:
                ProgressView()
                
            default:
                GetHelpView(
                    title: "Cannot sign up",
                    description: """
                    
                    Cannot proceed with sign up. We're unable to verify the provided information.
                    
                    If you’re experiencing difficulty signing up, email us and we will work with you to get you access as soon as possible.
                    """,
                    primaryButtonConfig: .init(label: "Email support", action: {
                        openURL(URL(string: "mailto:")!)
                    }),
                    secondaryButtonConfig: .init(label: "Back to sign up", action: {
                        clerkUIState.presentedAuthStep = .signUpStart
                    })
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity.animation(nil)
                ))
            }
        }
        .animation(.snappy, value: signUp?.nextStrategyToVerify)
        .onChange(of: signUp?.nextStrategyToVerify) { _ in
            KeyboardHelpers.dismissKeyboard()
            FeedbackGenerator.success()
        }
    }
}

#Preview {
    return SignUpVerificationView()
        .environment(ClerkUIState())
}

#endif
