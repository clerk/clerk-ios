//
//  SignInPasswordView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignInPasswordView: View {
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
                
                HeaderView(
                    title: "Enter password",
                    subtitle: "Enter the password associated with your ID"
                )
                .padding(.bottom, 4)
                
                IdentityPreviewView(
                    imageUrl: signIn.userData?.imageUrl,
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
                                .foregroundStyle(clerkTheme.colors.gray700)
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
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ClerkPrimaryButtonStyle())
                }
                .padding(.bottom, 18)
                
                AsyncButton {
                    clerkUIState.presentedAuthStep = .signInStart
                } label: {
                    Text("Use another method")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(clerkTheme.colors.gray700)
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
            try await signIn.attemptFirstFactor(.password(password: password))
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
}

#Preview {
    SignInPasswordView()
        .environmentObject(Clerk.mock)
        .environmentObject(ClerkUIState())
}

#endif
