//
//  SignInStartView.swift
//
//
//  Created by Mike Pitre on 9/22/23.
//

#if canImport(UIKit)

import SwiftUI

struct SignInStartView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    
    private var socialProvidersEnabled: Bool {
        !clerk.environment.userSettings.enabledThirdPartyProviders.isEmpty
    }
    
    private var showSignInForm: Bool {
        clerk.environment.userSettings.firstFactorAttributes.contains {
            $0.key == .emailAddress ||
            $0.key == .username ||
            $0.key == .phoneNumber
        }
    }
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .frame(width: 32, height: 32)
                    .padding(.bottom, 24)
                
                HeaderView(
                    title: "Sign in to \(clerk.environment.displayConfig.applicationName)",
                    subtitle: "Welcome back! Please sign in to continue"
                )
                .padding(.bottom, 32)
                
                if socialProvidersEnabled {
                    AuthSocialProvidersView(useCase: .signIn)
                        .onSuccess { clerkUIState.setAuthStepToCurrentStatus(for: signIn) }
                }
                
                if socialProvidersEnabled && showSignInForm {
                    TextDivider(text: "or")
                        .padding(.vertical, 24)
                }
                
                if showSignInForm {
                    SignInFormView()
                        .padding(.bottom, 32)
                }
                
                if clerk.localAuthConfig.localAuthCredentialsIsEnabled {
                    Button {
                        Task {
                            do {
                                try await LocalAuth.authenticateWithFaceID()
                            } catch {
                                // fallback
                            }
                        }
                    } label: {
                        Image(systemName: "faceid")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .tint(.secondary)
                    }
                    .padding(.vertical)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .padding(.top, 30)
        }
    }
}

#Preview {
    SignInStartView()
}

#endif
