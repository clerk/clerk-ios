//
//  SignInView.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

#if canImport(UIKit)

import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.clerkTheme) private var clerkTheme
    
    // Note: For some reason, attaching the transition modifier to every view individually works, but attached it once to the Group does not work consistently.
    
    var body: some View {
        Group {
            switch clerkUIState.presentedAuthStep {
            case .signInStart:
                SignInStartView()
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signInFactorOne:
                SignInFactorOneView()
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signInFactorOneUseAnotherMethod(let currentFactor):
                SignInFactorOneUseAnotherMethodView(currentFactor: currentFactor)
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signInFactorTwo:
                SignInFactorTwoView()
                    .transition(.asymmetric(
                        insertion: .offset(y: 50).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signInFactorTwoUseAnotherMethod(let currentFactor):
                SignInFactorTwoUseAnotherMethodView(currentFactor: currentFactor)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            Color(.systemBackground)
                .raisedCardBottom()
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
        }
        .keyboardIgnoringBottomView(inFrontOfContent: false, content: {
            VStack(spacing: 0) {
                footerView
                if clerk.environment.displayConfig.branded {
                    SecuredByClerkView()
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                }
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
                    .foregroundStyle(clerkTheme.colors.textSecondary)
                    .animation(nil, value: clerkUIState.presentedAuthStep)
                Button {
                    clerkUIState.presentedAuthStep = isSignIn ? .signUpStart : .signInStart
                } label: {
                    Text(isSignIn ? "Sign Up" : "Sign In")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(clerkTheme.colors.textPrimary)
                        .animation(nil, value: clerkUIState.presentedAuthStep)
                }
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .overlay(alignment: .bottom) {
                Divider()
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(Clerk.mock)
        .environmentObject(ClerkUIState())
}

#endif
