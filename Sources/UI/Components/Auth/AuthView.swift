//
//  SignInView.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

#if os(iOS)

import SwiftUI

extension AuthView {
    @MainActor
    final class Config: ObservableObject {
        // Sign In State
        @Published var signInEmailAddressOrUsername = ""
        @Published var signInPhoneNumber = ""
        @Published var signInPassword = ""
        @Published var signInFactorOneEmailCode = ""
        @Published var signInFactorOnePhoneCode = ""
        @Published var signInFactorOneResetCode = ""
        @Published var signInFactorTwoBackupCode = ""
        @Published var signInFactorTwoPhoneCode = ""
        @Published var signInFactorTwoTOTPCode = ""
        @Published var signInResetPasswordPassword = ""
        @Published var signInResetPasswordConfirmPassword = ""
        
        // Sign Up State
        @Published var signUpEmailAddress = ""
        @Published var signUpPhoneNumber = ""
        @Published var signUpUsername = ""
        @Published var signUpFirstName = ""
        @Published var signUpLastName = ""
        @Published var signUpPassword = ""
        @Published var signUpEmailCode = ""
        @Published var signUpPhoneCode = ""
    }
}

struct AuthView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.clerkTheme) private var clerkTheme
    @StateObject private var config = Config()
    
    // Note: For some reason, attaching the transition modifier to every view individually works, but attached it once to the Group does not work consistently.
    
    var body: some View {
        Group {
            switch clerkUIState.presentedAuthStep {
            case .signInStart:
                SignInStartView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signInFactorOne:
                SignInFactorOneView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signInFactorOneUseAnotherMethod(let currentFactor):
                SignInFactorOneUseAnotherMethodView(currentFactor: currentFactor)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signInFactorTwo:
                SignInFactorTwoView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signInFactorTwoUseAnotherMethod(let currentFactor):
                SignInFactorTwoUseAnotherMethodView(currentFactor: currentFactor)
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signInForgotPassword:
                SignInForgotPasswordView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signInResetPassword:
                SignInResetPasswordView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signUpStart:
                SignUpStartView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .signUpVerification:
                SignUpVerificationView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            case .ssoCallback:
                SSOCallbackView()
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.95).combined(with: .opacity),
                        removal: .opacity.animation(nil)
                    ))
            }
        }
        .environmentObject(config)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .keyboardIgnoringBottomView(inFrontOfContent: true, content: {
            VStack(spacing: 0) {
                footerView
                if clerk.environment?.displayConfig.branded == true {
                    SecuredByClerkView()
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .top) {
                            Divider()
                        }
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
            _ = try? await Clerk.Environment.get()
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
            .overlay(alignment: .top) {
                Divider()
            }
        }
    }
}

#Preview {
    AuthView()
        .environmentObject(ClerkUIState())
}

#endif
