//
//  SignInView.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

public struct AuthView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        Group {
            switch clerkUIState.presentedAuthStep {
            case .signInStart:
                SignInStartView()
            case .signInFactorOne:
                SignInFactorOneView()
            case .signInFactorTwo:
                SignInFactorTwoView()
            case .signInForgotPassword:
                SignInForgotPasswordView()
            case .signUpStart:
                SignUpStartView()
            case .signUpVerification:
                SignUpVerificationView()
            }
        }
        .frame(maxWidth: .infinity)
        .background(.background)
        .transition(.asymmetric(
            insertion: .offset(y: 50).combined(with: .opacity),
            removal: .opacity
        ))
        .animation(.snappy, value: clerkUIState.presentedAuthStep)
        .dismissButtonOverlay()
        .onChange(of: clerkUIState.presentedAuthStep) { _ in
            KeyboardHelpers.dismissKeyboard()
            FeedbackGenerator.success()
        }
        .task {
            try? await clerk.environment.get()
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(Clerk.mock)
        .environmentObject(ClerkUIState())
}

#endif
