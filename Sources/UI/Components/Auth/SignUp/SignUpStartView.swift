//
//  SignUpStartView.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

#if os(iOS)

import SwiftUI

struct SignUpStartView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    
    @State private var captchaToken: String?
    @State private var captchaIsInteractive = false
    @State private var displayCaptcha = false
    @State private var errorWrapper: ErrorWrapper?
    
    private var signUp: SignUp? {
        clerk.client?.signUp
    }
    
    private var signIn: SignIn? {
        clerk.client?.signIn
    }
    
    private var socialProvidersEnabled: Bool {
        clerk.environment?.userSettings.enabledThirdPartyProviders.isEmpty == false
    }
    
    private var contactInfoEnabled: Bool {
        clerk.environment?.userSettings.config(for: .emailAddress)?.enabled == true ||
        clerk.environment?.userSettings.config(for: .phoneNumber)?.enabled == true
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .frame(width: 32, height: 32)
                    .padding(.bottom, 24)
                
                HeaderView(
                    title: "Create your account",
                    subtitle: "Welcome! Please fill in the details to get started."
                )
                .padding(.bottom, 32)
                
                if socialProvidersEnabled {
                    AuthSocialProvidersView(captchaToken: $captchaToken, displayCaptcha: $displayCaptcha)
                        .onSuccess { provider, wasTransfer in
                            if wasTransfer {
                                clerkUIState.setAuthStepToCurrentStatus(for: signIn)
                            } else {
                                clerkUIState.setAuthStepToCurrentStatus(for: signUp)
                            }
                        }
                }
                
                if socialProvidersEnabled && contactInfoEnabled {
                    TextDivider(text: "or")
                        .padding(.vertical, 24)
                }

                if contactInfoEnabled {
                    SignUpFormView(captchaToken: $captchaToken, displayCaptcha: $displayCaptcha)
                        .padding(.bottom, 32)
                }
                
                if clerk.environment?.displayConfig.botProtectionIsEnabled == true, displayCaptcha {
                    TurnstileWebView()
                        .onSuccess { token in
                            captchaToken = token
                        }
                        .onBeforeInteractive {
                            captchaIsInteractive = true
                        }
                        .onError { errorMessage in
                            errorWrapper = ErrorWrapper(error: ClerkClientError(message: errorMessage))
                            dump(errorMessage)
                        }
                        .frame(width: 300, height: 65)
                        .scaleEffect(captchaIsInteractive ? 1 : 0)
                        .animation(.bouncy.speed(1.5), value: captchaIsInteractive)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            .padding(.vertical, 32)
            .clerkErrorPresenting($errorWrapper)
        }
    }
}

#Preview {
    SignUpStartView()
}

#endif
