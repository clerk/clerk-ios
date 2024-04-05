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
        clerk.environment?.userSettings.enabledThirdPartyProviders.isEmpty == false
    }
    
    private var showSignInForm: Bool {
        (clerk.environment?.userSettings.firstFactorAttributes ?? [:]).contains {
            $0.key == .emailAddress ||
            $0.key == .username ||
            $0.key == .phoneNumber
        }
    }
    
    private var signIn: SignIn? {
        clerk.client?.signIn
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
