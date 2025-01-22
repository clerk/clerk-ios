//
//  SignInStartView.swift
//
//
//  Created by Mike Pitre on 9/22/23.
//

#if os(iOS)

import SwiftUI
import Clerk
import AuthenticationServices

struct SignInStartView: View {
    var clerk = Clerk.shared
    @Environment(ClerkUIState.self) private var clerkUIState
    @Environment(AuthView.Config.self) private var config
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
                    AuthSocialProvidersView(useCase: .signIn)
                        .onSuccess { result in
                            switch result {
                            case .signIn:
                                clerkUIState.setAuthStepToCurrentSignInStatus()
                            case .signUp:
                                clerkUIState.setAuthStepToCurrentSignUpStatus()
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
    }
}

#Preview {
    SignInStartView()
}

#endif
