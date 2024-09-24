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
        
        // Sign Up State
        @Published var signUpEmailAddress = ""
        @Published var signUpPhoneNumber = ""
        @Published var signUpUsername = ""
        @Published var signUpFirstName = ""
        @Published var signUpLastName = ""
        @Published var signUpPassword = ""
        @Published var signUpEmailCode = ""
        @Published var signUpPhoneCode = ""
        
        func resetState() {
            signInEmailAddressOrUsername = ""
            signInPhoneNumber = ""
            signInPassword = ""
            signInFactorOneEmailCode = ""
            signInFactorOnePhoneCode = ""
            signInFactorOneResetCode = ""
            signInFactorTwoBackupCode = ""
            signInFactorTwoPhoneCode = ""
            signInFactorTwoTOTPCode = ""
            
            signUpEmailAddress = ""
            signUpPhoneNumber = ""
            signUpUsername = ""
            signUpFirstName = ""
            signUpLastName = ""
            signUpPassword = ""
            signUpEmailCode = ""
            signUpPhoneCode = ""
        }
    }
}

struct AuthView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.clerkTheme) private var clerkTheme
    @StateObject private var config = Config()
    
    func viewForAuthStep(_ authStep: ClerkUIState.AuthStep) -> AnyView {
        // Note: For some reason, attaching the transition modifier to every view individually works, but attached it once to the Group does not work consistently.
        
        switch clerkUIState.presentedAuthStep {
        case .signInStart:
            SignInStartView()
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity.animation(nil)
                ))
                .eraseToAnyView()
        case .signInFactorOne(let factor):
            SignInFactorOneView(factor: factor)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity.animation(nil)
                ))
                .eraseToAnyView()
        case .signInFactorOneUseAnotherMethod(let currentFactor):
            SignInFactorOneUseAnotherMethodView(currentFactor: currentFactor)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity.animation(nil)
                ))
                .eraseToAnyView()
        case .signInFactorTwo(let factor):
            SignInFactorTwoView(factor: factor)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity.animation(nil)
                ))
                .eraseToAnyView()
        case .signInFactorTwoUseAnotherMethod(let currentFactor):
            SignInFactorTwoUseAnotherMethodView(currentFactor: currentFactor)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity.animation(nil)
                ))
                .eraseToAnyView()
        case .signInForgotPassword(let factor):
            SignInForgotPasswordView(factor: factor)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity.animation(nil)
                ))
                .eraseToAnyView()
        case .signInResetPassword:
            SignInResetPasswordView()
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity.animation(nil)
                ))
                .eraseToAnyView()
        case .signUpStart:
            SignUpStartView()
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity.animation(nil)
                ))
                .eraseToAnyView()
        case .signUpVerification:
            SignUpVerificationView()
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity.animation(nil)
                ))
                .eraseToAnyView()
        case .signUpCreatePasskey:
            SignUpCreatePasskeyView()
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity.animation(nil)
                ))
                .eraseToAnyView()
        case .ssoCallback:
            SSOCallbackView()
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.95).combined(with: .opacity),
                    removal: .opacity.animation(nil)
                ))
                .eraseToAnyView()
        }
    }
    
    var body: some View {
        viewForAuthStep(clerkUIState.presentedAuthStep)
            .id(clerkUIState.presentedAuthStep)
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
            .dismissButtonOverlay {
                // clear the state before dismissing so Apple's keychain Heuristics
                // dont think we changed a password if the user manually dismissed
                config.resetState()
            }
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
