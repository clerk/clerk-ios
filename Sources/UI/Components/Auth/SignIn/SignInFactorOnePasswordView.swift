//
//  SignInFactorOnePasswordView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if os(iOS)

import SwiftUI
import SimpleKeychain

struct SignInFactorOnePasswordView: View {
    var clerk = Clerk.shared
    @Environment(ClerkUIState.self) private var clerkUIState
    @Environment(AuthView.Config.self) private var config
    @Environment(ClerkTheme.self) private var clerkTheme
    @State private var errorWrapper: ErrorWrapper?
    @FocusState private var isFocused: Bool
        
    let factor: SignInFactor
    
    private var signIn: SignIn? {
        clerk.client?.signIn
    }
    
    var body: some View {
        @Bindable var config = config
        
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .frame(width: 32, height: 32)
                    .padding(.bottom, 24)
                
                HeaderView(
                    title: "Enter password",
                    subtitle: "Enter the password associated with your ID"
                )
                .padding(.bottom, 4)
                
                IdentityPreviewView(
                    label: signIn?.identifier,
                    action: {
                        clerkUIState.presentedAuthStep = .signInStart
                    }
                )
                .padding(.bottom, 32)
                
                VStack(spacing: 32) {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Password")
                                .foregroundStyle(clerkTheme.colors.textPrimary)
                            Spacer()
                            Button(action: {
                                if let resetFactor = signIn?.resetFactor {
                                    clerkUIState.presentedAuthStep = .signInForgotPassword(factor: resetFactor)
                                } else {
                                    errorWrapper = ErrorWrapper(error: ClerkClientError(message: "Unable to determine the reset factor."))
                                }
                            }, label: {
                                Text("Forgot password?")
                            })
                            .tint(clerkTheme.colors.textPrimary)
                        }
                        .font(.footnote.weight(.medium))
                        
                        PasswordInputView(password: $config.signInPassword)
                            .textContentType(.password)
                            .focused($isFocused)
                            .task { isFocused = true }
                    }
                    
                    AsyncButton(action: attempt) {
                        Text("Continue")
                            .clerkStandardButtonPadding()
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkPrimaryButtonStyle())
                }
                .padding(.bottom, 18)
                
                AsyncButton {
                    clerkUIState.presentedAuthStep = .signInFactorOneUseAnotherMethod(
                        currentFactor: factor
                    )
                } label: {
                    Text("Use another method")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(clerkTheme.colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .padding(.top, 30)
            .background(.background)
            .clerkErrorPresenting($errorWrapper)
        }
    }
    
    private func attempt() async {
        do {
            try await signIn?.attemptFirstFactor(
                for: .password(password: config.signInPassword)
            )
            
            clerkUIState.setAuthStepToCurrentSignInStatus()
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
}

#Preview {
    SignInFactorOnePasswordView(factor: .mock)
        .environment(AuthView.Config())
        .environment(ClerkUIState())
}

#endif
