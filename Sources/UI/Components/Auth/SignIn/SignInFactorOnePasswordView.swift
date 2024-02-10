//
//  SignInFactorOnePasswordView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if canImport(UIKit)

import SwiftUI

struct SignInFactorOnePasswordView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    
    @State private var password: String = ""
    @State private var errorWrapper: ErrorWrapper?
    @FocusState private var isFocused: Bool
    
    var signIn: SignIn {
        clerk.client.signIn
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .padding(.bottom, 24)
                
                HeaderView(
                    title: "Enter password",
                    subtitle: "Enter the password associated with your ID"
                )
                .padding(.bottom, 4)
                
                IdentityPreviewView(
                    label: signIn.identifier,
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
                                clerkUIState.presentedAuthStep = .signInForgotPassword
                            }, label: {
                                Text("Forgot password?")
                            })
                            .tint(clerkTheme.colors.textPrimary)
                        }
                        .font(.footnote.weight(.medium))
                        
                        PasswordInputView(password: $password)
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
                    clerkUIState.presentedAuthStep = .signInFactorOneUseAnotherMethod(signIn.firstFactor(for: .password))
                } label: {
                    Text("Use another method")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(clerkTheme.colors.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .padding(.vertical)
            .background(.background)
            .clerkErrorPresenting($errorWrapper)
        }
    }
    
    private func attempt() async {
        do {
            try await signIn.attemptFirstFactor(for: .password(password: password))
            if signIn.status == .needsSecondFactor {
                clerkUIState.presentedAuthStep = .signInFactorTwo(signIn.currentSecondFactor)
            } else {
                clerkUIState.authIsPresented = false
            }
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
}

#Preview {
    SignInFactorOnePasswordView()
        .environmentObject(Clerk.mock)
        .environmentObject(ClerkUIState())
}

#endif
