//
//  SignUpStartView.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

#if canImport(UIKit)

import SwiftUI

struct SignUpStartView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    
    private var signUp: SignUp {
        clerk.client.signUp
    }
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    private var socialProvidersEnabled: Bool {
        !clerk.environment.userSettings.enabledThirdPartyProviders.isEmpty
    }
    
    private var contactInfoEnabled: Bool {
        clerk.environment.userSettings.config(for: .emailAddress)?.enabled == true ||
        clerk.environment.userSettings.config(for: .phoneNumber)?.enabled == true
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .padding(.bottom, 24)
                
                HeaderView(
                    title: "Create your account",
                    subtitle: "Welcome! Please fill in the details to get started."
                )
                .padding(.bottom, 32)
                
                if socialProvidersEnabled {
                    AuthSocialProvidersView(useCase: .signUp)
                        .onSuccess {
                            if signUp.status == .complete {
                                clerkUIState.authIsPresented = false
                            } else {
                                // if the signup isnt complete
                                clerkUIState.setAuthStepToCurrentStatus(for: signIn)
                            }
                        }
                }
                
                if socialProvidersEnabled && contactInfoEnabled {
                    TextDivider(text: "or")
                        .padding(.vertical, 24)
                }

                if contactInfoEnabled {
                    SignUpFormView()
                        .padding(.bottom, 32)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.vertical, 32)
        }
    }
}

#Preview {
    SignUpStartView()
        .environmentObject(Clerk.mock)
}

#endif
