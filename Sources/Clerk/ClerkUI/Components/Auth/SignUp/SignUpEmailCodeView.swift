//
//  SignUpEmailCodeView.swift
//
//
//  Created by Mike Pitre on 11/1/23.
//

#if os(iOS)

import SwiftUI

struct SignUpEmailCodeView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(ClerkUIState.self) private var clerkUIState
    @Environment(AuthView.Config.self) private var config
    @State private var errorWrapper: ErrorWrapper?
    
    private var signUp: SignUp? {
        clerk.client?.signUp
    }
    
    var body: some View {
        @Bindable var config = config
        
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .frame(width: 32, height: 32)
                    .padding(.bottom, 24)
                
                VerificationCodeView(
                    code: $config.signUpEmailCode,
                    title: "Verify your email",
                    subtitle: "Enter the verification code sent to your email address",
                    safeIdentifier: signUp?.emailAddress
                )
                .onContinueAction {
                    //
                }
                .onIdentityPreviewTapped {
                    clerkUIState.presentedAuthStep = .signUpStart
                }
                .onCodeEntry {
                    await attempt()
                }
                .onResend {
                    await prepare()
                }
                .clerkErrorPresenting($errorWrapper)
                .task {
                    await prepare()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 32)
        }
    }
    
    private func prepare() async {
        do {
            try await signUp?.prepareVerification(strategy: .emailCode)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            try await signUp?.attemptVerification(
                .emailCode(code: config.signUpEmailCode)
            )
            
            clerkUIState.setAuthStepToCurrentSignUpStatus()
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            config.signUpEmailCode = ""
            dump(error)
        }
    }
}

#Preview {
    return SignUpEmailCodeView()
        .environment(ClerkUIState())
}

#endif
