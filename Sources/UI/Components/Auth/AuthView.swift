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
    @Environment(\.clerkTheme) private var clerkTheme
    
    // Note: For some reason, attaching the transition modifier to every view individually works, but attached it once to the Group does not work consistently.
    
    public var body: some View {
        Group {
            switch clerkUIState.presentedAuthStep {
            case .signInStart:
                SignInStartView()
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signInPassword:
                SignInPasswordView()
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signInUseAnotherMethod(let currentStrategy):
                SignInUseAnotherMethodView(currentStrategy: currentStrategy)
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signInFactorOneVerify:
                SignInFactorOneVerificationView()
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signInFactorTwoVerify:
                SignInFactorTwoView()
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signInForgotPassword:
                SignInForgotPasswordView()
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signInResetPassword:
                SignInResetPasswordView()
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signUpStart:
                SignUpStartView()
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signUpVerification:
                SignUpVerificationView()
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            Color(.systemBackground)
                .raisedCardBottom()
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
        }
        .keyboardAvoidingBottomView(inFrontOfContent: false, content: {
            VStack(spacing: 0) {
                footerView
                SecuredByClerkView()
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
            }
            .background(.ultraThinMaterial)
        })
        .animation(.snappy, value: clerkUIState.presentedAuthStep)
        .dismissButtonOverlay()
        .interactiveDismissDisabled()
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: clerkUIState.presentedAuthStep) { _ in
            KeyboardHelpers.dismissKeyboard()
            FeedbackGenerator.success()
        }
        .task {
            try? await clerk.environment.get()
        }
    }
    
    @ViewBuilder
    private var footerView: some View {
        var isSignIn: Bool {
            clerkUIState.presentedAuthStep == .signInStart
        }
        
        if [.signInStart, .signUpStart].contains(clerkUIState.presentedAuthStep) {
            HStack(spacing: 4) {
                Text(isSignIn ? "Don't have an account?" : "Already have an account?")
                    .font(.footnote)
                    .foregroundStyle(clerkTheme.colors.gray500)
                Button {
                    clerkUIState.authIsPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                        clerkUIState.presentedAuthStep = isSignIn ? .signUpStart : .signInStart
                    })
                } label: {
                    Text(isSignIn ? "Sign Up" : "Sign In")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(clerkTheme.colors.gray700)
                }
            }
            .padding(.vertical, 16)
            
            Divider()
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(Clerk.mock)
        .environmentObject(ClerkUIState())
}

#endif
