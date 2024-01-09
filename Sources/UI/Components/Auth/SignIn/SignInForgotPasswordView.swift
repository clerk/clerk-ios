//
//  SignInForgotPasswordView.swift
//
//
//  Created by Mike Pitre on 12/15/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import NukeUI
import AuthenticationServices

struct SignInForgotPasswordView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    @State private var errorWrapper: ErrorWrapper?
    
    private var thirdPartyProviders: [OAuthProvider] {
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
            try await signIn.prepareFirstFactor(resetPasswordStrategy)
            clerkUIState.presentedAuthStep = .signInFactorOne(signIn.currentFirstFactor)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .padding(.bottom, 24)
                
                Text("Forgot password?")
                    .font(.body.weight(.bold))
                    .foregroundStyle(clerkTheme.colors.gray700)
                    .padding(.bottom, 32)
                
                AsyncButton {
                    await resetPassword()
                } label: {
                    Text("Reset password")
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
                        .foregroundStyle(clerkTheme.colors.gray700)
                        .frame(minHeight: ClerkStyleConstants.textMinHeight)
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
        .environmentObject(Clerk.mock)
}

#endif
