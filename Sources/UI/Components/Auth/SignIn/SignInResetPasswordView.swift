//
//  SignInNewPasswordView.swift
//
//
//  Created by Mike Pitre on 12/18/23.
//

#if canImport(UIKit)

import SwiftUI

struct SignInResetPasswordView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var signOutOfAllDevices = true
    @State private var errorWrapper: ErrorWrapper?
    
    private var signIn: SignIn? {
        clerk.client?.signIn
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
                        
                        CustomTextField(
                            text: $password,
                            isSecureField: true
                        )
                        .textContentType(.newPassword)
                    }
                    
                    VStack(spacing: 8) {
                        HStack {
                            Text("Confirm password")
                                .font(.footnote)
                                .foregroundStyle(clerkTheme.colors.textPrimary)
                            Spacer()
                        }
                        
                        CustomTextField(
                            text: $confirmPassword,
                            isSecureField: true
                        )
                        .textContentType(.newPassword)
                    }
                }
                .padding(.bottom, 24)
                
                HStack {
                    HStack(spacing: 10) {
                        CheckBoxView(isSelected: $signOutOfAllDevices)
                            .frame(width: 18, height: 18)
                            .onChange(of: signOutOfAllDevices) { _ in
                                #if !os(tvOS)
                                FeedbackGenerator.success()
                                #endif
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
                    clerkUIState.presentedAuthStep = .signInFactorOne(signIn?.firstFactor(for: .password))
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
}

#Preview {
    SignInResetPasswordView()
}

#endif

