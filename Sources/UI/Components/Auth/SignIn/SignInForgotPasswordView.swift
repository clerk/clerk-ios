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
    
    private func signIn(provider: OAuthProvider) async {
        do {
            try await signIn.create(.oauth(provider: provider))
            try await signIn.startOAuth()
        } catch {
            clerkUIState.presentedAuthStep = .signInStart
            dump(error)
        }
    }
    
    private func startAlternateFirstFactor(_ factor: Factor) async {
        do {
            if let prepareStrategy = factor.prepareFirstFactorStrategy {
                try await signIn.prepareFirstFactor(prepareStrategy)
            }
            
            clerkUIState.presentedAuthStep = .signInFactorOneVerify
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func resetPassword() async {
        do {
            guard let resetPasswordStrategy = signIn.resetPasswordStrategy else {
                throw ClerkClientError(message: "Unable to determine the reset password strategy for this account.")
            }
            try await signIn.prepareFirstFactor(resetPasswordStrategy)
            clerkUIState.presentedAuthStep = .signInFactorOneVerify
        } catch {
            errorWrapper = ErrorWrapper(error: error)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                
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
                
                VStack(spacing: 8) {
                    ForEach(thirdPartyProviders) { provider in
                        AsyncButton {
                            await signIn(provider: provider)
                        } label: {
                            HStack {
                                LazyImage(url: provider.iconImageUrl) { state in
                                    if let image = state.image {
                                        image.resizable().scaledToFit()
                                    } else {
                                        Color(.secondarySystemBackground)
                                    }
                                }
                                .frame(width: 16, height: 16)
                                
                                Text("Continue with \(provider.data.name)")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(ClerkSecondaryButtonStyle())
                    }
                    
                    ForEach(signIn.alternativeFirstFactors(currentStrategy: .password), id: \.self) { factor in
                        if let actionText = factor.actionText {
                            AsyncButton {
                                await startAlternateFirstFactor(factor)
                            } label: {
                                HStack {
                                    Image(systemName: factor.verificationStrategy?.icon ?? "")
                                        .frame(width: 16, height: 16)
                                    
                                    Text(actionText)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ClerkSecondaryButtonStyle())
                        }
                    }
                }
                .padding(.bottom, 18)
                
                Button {
                    clerkUIState.presentedAuthStep = .signInPassword
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
        .safeAreaInset(edge: .bottom) {
            SecuredByClerkView()
                .padding()
                .frame(maxWidth: .infinity)
                .background()
        }
    }
}

#Preview {
    SignInForgotPasswordView()
        .environmentObject(Clerk.mock)
}

#endif
