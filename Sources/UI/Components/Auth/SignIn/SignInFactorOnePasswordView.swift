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
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    
    @State private var password: String = ""
    @State private var errorWrapper: ErrorWrapper?
    @FocusState private var isFocused: Bool
    @State private var enableBiometry: Bool = true
    
    var signIn: SignIn? {
        clerk.client?.signIn
    }
    
    var body: some View {
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
                                clerkUIState.presentedAuthStep = .signInForgotPassword
                            }, label: {
                                Text("Forgot password?")
                            })
                            .tint(clerkTheme.colors.textPrimary)
                        }
                        .font(.footnote.weight(.medium))
                        
                        PasswordInputView(password: $password)
                            .textContentType(.password)
                            .focused($isFocused)
                            .task { isFocused = true }
                        
                        if Clerk.LocalAuth.availableBiometryType != .none {
                            HStack {
                                Toggle(isOn: $enableBiometry, label: { EmptyView() })
                                    .labelsHidden()
                                
                                Text("Enable \(Clerk.LocalAuth.availableBiometryType.displayName)")
                                    .font(.footnote.weight(.medium))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top)
                        }
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
                    clerkUIState.presentedAuthStep = .signInFactorOneUseAnotherMethod(signIn?.firstFactor(for: .password))
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
            let signInIdentifier = signIn?.identifier
            
            try await signIn?.attemptFirstFactor(for: .password(password: password))
            
            if let signInIdentifier, enableBiometry {
                try Clerk.LocalAuth.setLocalAuthCredentials(identifier: signInIdentifier, password: password)
            }
            
            if signIn?.status == .needsSecondFactor {
                clerkUIState.presentedAuthStep = .signInFactorTwo(signIn?.currentSecondFactor)
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
        .environmentObject(ClerkUIState())
}

#endif
