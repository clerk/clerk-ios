//
//  SignUpStartView.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

#if os(iOS)

import SwiftUI
import Clerk

struct SignUpStartView: View {
    var clerk = Clerk.shared
    @Environment(ClerkUIState.self) private var clerkUIState
    @Environment(ClerkTheme.self) private var clerkTheme
    
    @State private var formIsSubmitting = false
    @State private var captchaToken: String?
    @State private var showCaptcha = false
    @State private var captchaIsActive = false
    @State private var errorWrapper: ErrorWrapper?
    
    private var socialProvidersEnabled: Bool {
        clerk.environment?.userSettings.authenticatableSocialProviders.isEmpty == false
    }
    
    private var contactInfoEnabled: Bool {
        clerk.environment?.userSettings.config(for: "email_address")?.enabled == true ||
        clerk.environment?.userSettings.config(for: "phone_number")?.enabled == true
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
                    AuthSocialProvidersView(useCase: .signUp)
                        .onSuccess { result in
                            if result.signIn != nil {
                                clerkUIState.setAuthStepToCurrentSignInStatus()
                            } else if result.signUp != nil {
                                clerkUIState.setAuthStepToCurrentSignUpStatus()
                            }
                        }
                }
                
                if socialProvidersEnabled && contactInfoEnabled {
                    TextDivider(text: "or")
                        .padding(.vertical, 24)
                }

                if contactInfoEnabled {
                    SignUpFormView(
                        isSubmitting: $formIsSubmitting, 
                        captchaToken: $captchaToken,
                        captchaIsActive: $captchaIsActive
                    )
                    .padding(.bottom, 32)
                }
                
                if clerk.environment?.displayConfig.captchaWidgetType != nil, captchaIsActive {
                    TurnstileWebView(widgetType: .invisible)
                        .onSuccess { token in
                            captchaToken = token
                        }
                        .onDidFinishLoading {
                            showCaptcha = true
                        }
                        .onError { errorMessage in
                            errorWrapper = ErrorWrapper(error: ClerkClientError(message: errorMessage))
                            formIsSubmitting = false
                            dump(errorMessage)
                        }
                        .frame(width: 300, height: 65)
                        .scaleEffect(showCaptcha ? 1 : 0)
                        .animation(.bouncy.speed(1.5), value: showCaptcha)
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
