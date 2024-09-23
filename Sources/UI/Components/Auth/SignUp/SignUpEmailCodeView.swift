//
//  SignUpEmailCodeView.swift
//
//
//  Created by Mike Pitre on 11/1/23.
//

#if os(iOS)

import SwiftUI

struct SignUpEmailCodeView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @EnvironmentObject private var config: AuthView.Config
    @State private var errorWrapper: ErrorWrapper?
    
    let signUp: SignUp
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .frame(width: 32, height: 32)
                    .padding(.bottom, 24)
                
                VerificationCodeView(
                    code: $config.signUpEmailCode,
                    title: "Verify your email",
                    subtitle: "Enter the verification code sent to your email address",
                    safeIdentifier: signUp.emailAddress
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
            try await signUp.prepareVerification(strategy: .emailCode)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            let attemptedSignUp = try await signUp.attemptVerification(
                .emailCode(code: config.signUpEmailCode)
            )
            
            clerkUIState.setAuthStepToCurrentStatus(for: attemptedSignUp)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            config.signUpEmailCode = ""
            dump(error)
        }
    }
}

#Preview {
    return SignUpEmailCodeView(signUp: .mock)
        .environmentObject(ClerkUIState())
}

#endif
