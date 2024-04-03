//
//  SignUpVerificationView.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

#if canImport(UIKit)

import SwiftUI
import Factory

struct SignUpVerificationView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.openURL) private var openURL
    @State private var errorWrapper: ErrorWrapper?
        
    private var signUp: SignUp {
        clerk.client.signUp
    }
    
    var body: some View {
        Group {
            switch signUp.nextStrategyToVerify {
            case .phoneCode:
                SignUpPhoneCodeView()
            case .emailCode:
                SignUpEmailCodeView()
            case nil where signUp.status == .missingRequirements:
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
                .task { clerkUIState.setAuthStepToCurrentStatus(for: signUp) }
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity.animation(nil)
                ))
            default:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task { clerkUIState.setAuthStepToCurrentStatus(for: signUp) }
            }
        }
        .transition(.offset(y: 50).combined(with: .opacity))
        .animation(.snappy, value: signUp.nextStrategyToVerify)
        .onChange(of: signUp.nextStrategyToVerify) { _ in
            KeyboardHelpers.dismissKeyboard()
            FeedbackGenerator.success()
        }
    }
}

#Preview {
    return SignUpVerificationView()
        .environmentObject(ClerkUIState())
}

#endif
