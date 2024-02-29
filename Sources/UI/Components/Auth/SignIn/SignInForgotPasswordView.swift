//
//  SignInForgotPasswordView.swift
//
//
//  Created by Mike Pitre on 12/15/23.
//

#if canImport(UIKit)

import SwiftUI
import NukeUI
import AuthenticationServices

struct SignInForgotPasswordView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    @State private var errorWrapper: ErrorWrapper?
    
    private var thirdPartyProviders: [ExternalProvider] {
        clerk.environment.userSettings.enabledThirdPartyProviders.sorted()
    }
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    private func resetPassword() async {
        do {
            guard let resetPasswordStrategy = signIn.resetPasswordStrategy else {
                throw ClerkClientError(message: "Unable to determine the reset password strategy for this account.")
            }
            try await signIn.prepareFirstFactor(for: resetPasswordStrategy)
            clerkUIState.presentedAuthStep = .signInFactorOne(signIn.currentFirstFactor)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .frame(width: 32, height: 32)
                    .padding(.bottom, 24)
                
                Text("Forgot password?")
                    .font(.body.weight(.bold))
                    .foregroundStyle(clerkTheme.colors.textPrimary)
                    .padding(.bottom, 32)
                
                AsyncButton {
                    await resetPassword()
                } label: {
                    Text("Reset password")
                        .clerkStandardButtonPadding()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClerkPrimaryButtonStyle())
                
                TextDivider(text: "Or, sign in with another method")
                    .padding(.vertical, 24)
                
                SignInFactorOneAlternativeMethodsView(currentFactor: signIn.firstFactor(for: .password))
                    .padding(.bottom, 18)
                
                Button {
                    clerkUIState.presentedAuthStep = .signInFactorOne(signIn.firstFactor(for: .password))
                } label: {
                    Text("Back to previous method")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(clerkTheme.colors.textSecondary)
                        .frame(minHeight: 18)
                }
            }
            .padding()
            .padding(.vertical)
        }
        .clerkErrorPresenting($errorWrapper)
    }
}

#Preview {
    SignInForgotPasswordView()
        .environmentObject(Clerk.shared)
}

#endif
