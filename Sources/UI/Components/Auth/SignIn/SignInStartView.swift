//
//  SignInStartView.swift
//
//
//  Created by Mike Pitre on 9/22/23.
//

#if os(iOS)

import SwiftUI
import AuthenticationServices

struct SignInStartView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @EnvironmentObject private var config: AuthView.Config
    @State private var errorWrapper: ErrorWrapper?
    @State private var isLoading = false
    
    private var socialProvidersEnabled: Bool {
        clerk.environment?.userSettings.authenticatableSocialProviders.isEmpty == false
    }
    
    private var showSignInForm: Bool {
        (clerk.environment?.userSettings.firstFactorAttributes ?? [:]).contains {
            $0.key == "email_address" ||
            $0.key == "username" ||
            $0.key == "phone_number"
        }
    }
    
    private var headerTitle: String {
        var string = "Sign in"
        if let environment = clerk.environment {
            string += " to \(environment.displayConfig.applicationName)"
        }
        return string
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .frame(width: 32, height: 32)
                    .padding(.bottom, 24)
                
                HeaderView(
                    title: headerTitle,
                    subtitle: "Welcome back! Please sign in to continue"
                )
                .padding(.bottom, 32)
                
                if socialProvidersEnabled {
                    AuthSocialProvidersView()
                        .onSuccess { result in
                            if let signIn = result.signIn {
                                clerkUIState.setAuthStepToCurrentStatus(for: signIn)
                            } else if let signUp = result.signUp {
                                clerkUIState.setAuthStepToCurrentStatus(for: signUp)
                            }
                        }
                }
                
                if socialProvidersEnabled && showSignInForm {
                    TextDivider(text: "or")
                        .padding(.vertical, 24)
                }
                
                if showSignInForm {
                    SignInFormView(isLoading: $isLoading)
                        .padding(.bottom, 32)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .padding(.top, 30)
        }
        .clerkErrorPresenting($errorWrapper)
        .task {
            if clerk.environment?.userSettings.passkeySettings?.allowAutofill == true, !config.didAutoDisplayPasskey {
                config.didAutoDisplayPasskey = true
                try? await Task.sleep(for: .seconds(0.3))
                await signInWithPasskey()
            }
        }
    }
}

extension SignInStartView {
    
    private func signInWithPasskey() async {
        do {
            KeyboardHelpers.dismissKeyboard()
            
            let signIn = try await SignIn
                .create(strategy: .passkey)
            
            let credential = try await signIn
                .getCredentialForPasskey()

            isLoading = true
            
            let attemptedSignIn = try await signIn.attemptFirstFactor(
                for: .passkey(publicKeyCredential: credential)
            )
            
            clerkUIState.setAuthStepToCurrentStatus(for: attemptedSignIn)
        } catch {
            if case ASAuthorizationError.canceled = error { return }
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
        
        isLoading = false
    }
    
}

#Preview {
    SignInStartView()
}

#endif
