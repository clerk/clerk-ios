//
//  SignUpPhoneCodeView.swift
//
//
//  Created by Mike Pitre on 11/1/23.
//

#if os(iOS)

import SwiftUI

struct SignUpPhoneCodeView: View {
    var clerk = Clerk.shared
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
                    code: $config.signUpPhoneCode,
                    title: "Verify your phone number",
                    subtitle: "Enter the verification code sent to your phone number",
                    safeIdentifier: signUp?.phoneNumber
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
            try await signUp?.prepareVerification(strategy: .phoneCode)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            try await signUp?.attemptVerification(
                .phoneCode(code: config.signUpPhoneCode)
            )
            
            clerkUIState.setAuthStepToCurrentSignUpStatus()
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            config.signUpPhoneCode = ""
            dump(error)
        }
    }
}

#Preview {
    SignUpPhoneCodeView()
        .environment(ClerkUIState())
}

#endif
