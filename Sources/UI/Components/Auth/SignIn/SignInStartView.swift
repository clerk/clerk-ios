//
//  SignInStartView.swift
//
//
//  Created by Mike Pitre on 9/22/23.
//

#if canImport(UIKit)

import SwiftUI
import ClerkSDK

struct SignInStartView: View {
    @EnvironmentObject private var clerk: Clerk
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
    
    public var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
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
            }
            .padding()
            .padding(.vertical)
        }
    }
}

#Preview {
    SignInStartView()
        .environmentObject(Clerk.mock)
}

#endif
