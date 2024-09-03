//
//  SignInNewPasswordView.swift
//
//
//  Created by Mike Pitre on 12/18/23.
//

#if os(iOS)

import SwiftUI

struct SignInResetPasswordView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @EnvironmentObject private var config: AuthView.Config
    @Environment(\.clerkTheme) private var clerkTheme
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var signOutOfAllDevices = true
    @State private var errorWrapper: ErrorWrapper?
    
    private var signIn: SignIn? {
        clerk.client?.signIn
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .frame(width: 32, height: 32)
                    .padding(.bottom, 24)
                
                HeaderView(
                    title: "Set new password",
                    subtitle: "Your password needs to be at least 8 characters."
                )
                .padding(.bottom, 32)
                
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        HStack {
                            Text("New password")
                                .font(.footnote)
                                .foregroundStyle(clerkTheme.colors.textPrimary)
                            Spacer()
                        }
                        
                        PasswordInputView(password: $password)
                            .hiddenTextField(text: .constant(signIn?.identifier ?? ""), textContentType: .username)
                    }
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Confirm password")
                                .font(.footnote)
                                .foregroundStyle(clerkTheme.colors.textPrimary)
                            Spacer()
                        }
                        
                        PasswordInputView(password: $confirmPassword)
                            .textContentType(.newPassword)
                    }
                }
                .padding(.bottom, 24)
                
                HStack {
                    HStack(spacing: 10) {
                        CheckBoxView(isSelected: $signOutOfAllDevices)
                            .frame(width: 18, height: 18)
                            .onChange(of: signOutOfAllDevices) { _ in
                                FeedbackGenerator.success()
                            }
                        
                        Text("Sign out of all other devices")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.textPrimary)
                    }
                    Spacer()
                }
                .padding(.bottom, 32)
                
                AsyncButton {
                    await resetPassword()
                } label: {
                    Text("Reset password")
                        .clerkStandardButtonPadding()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClerkPrimaryButtonStyle())
                .padding(.bottom, 18)
                
                Button {
                    clerkUIState.presentedAuthStep = .signInStart
                } label: {
                    Text("Back to sign in")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(clerkTheme.colors.textPrimary)
                }

            }
            .padding(.horizontal)
            .padding(.vertical, 32)
        }
    }
    
    private func resetPassword() async {
        do {
            try await signIn?.resetPassword(.init(
                password: password,
                signOutOfOtherSessions: signOutOfAllDevices
            ))
            
            clerkUIState.setAuthStepToCurrentStatus(for: signIn)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
        }
    }
}

#Preview {
    SignInResetPasswordView()
}

#endif

