//
//  SignInFactorTwoPhoneCodeView.swift
//
//
//  Created by Mike Pitre on 1/8/24.
//

#if os(iOS)

import SwiftUI

struct SignInFactorTwoPhoneCodeView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @EnvironmentObject private var config: AuthView.Config
    @State private var errorWrapper: ErrorWrapper?
    
    let signIn: SignIn
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .frame(width: 32, height: 32)
                    .padding(.bottom, 24)
                
                VerificationCodeView(
                    code: $config.signInFactorTwoPhoneCode,
                    title: "Two-step verification",
                    subtitle: "To continue, please enter the verification code sent to your phone"
                )
                .onCodeEntry {
                    await attempt()
                }
                .onResend {
                    await prepare()
                }
                .onContinueAction {
                    //
                }
                .onUseAlernateMethod {
                    clerkUIState.presentedAuthStep = .signInFactorTwoUseAnotherMethod(
                        signIn: signIn,
                        currentFactor: signIn.secondFactor(for: .phoneCode)
                    )
                }
                .task {
                    if !signIn.secondFactorHasBeenPrepared {
                        await prepare()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 32)
            .clerkErrorPresenting($errorWrapper)
        }
    }
    
    private func prepare() async {
        do {
            try await signIn.prepareSecondFactor(for: .phoneCode)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            let attemptedSignIn = try await signIn.attemptSecondFactor(
                for: .phoneCode(code: config.signInFactorTwoPhoneCode)
            )
            clerkUIState.setAuthStepToCurrentStatus(for: attemptedSignIn)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            config.signInFactorTwoPhoneCode = ""
            dump(error)
        }
    }
}

#Preview {
    SignInFactorTwoPhoneCodeView(signIn: .mock)
}

#endif
