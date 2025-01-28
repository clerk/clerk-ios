//
//  SignInFactorTwoPhoneCodeView.swift
//
//
//  Created by Mike Pitre on 1/8/24.
//

#if os(iOS)

import SwiftUI

struct SignInFactorTwoPhoneCodeView: View {
    @Environment(Clerk.self) private var clerk
    @Environment(ClerkUIState.self) private var clerkUIState
    @Environment(AuthView.Config.self) private var config
    @State private var errorWrapper: ErrorWrapper?
    
    let factor: Factor
    
    private var signIn: SignIn? {
        clerk.client?.signIn
    }
    
    var body: some View {
        @Bindable var config = config
        
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
                        currentFactor: factor
                    )
                }
                .task {
                    if signIn?.secondFactorHasBeenPrepared == false {
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
            try await signIn?.prepareSecondFactor(for: .phoneCode)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            try await signIn?.attemptSecondFactor(
                for: .phoneCode(code: config.signInFactorTwoPhoneCode)
            )
            clerkUIState.setAuthStepToCurrentSignInStatus()
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            config.signInFactorTwoPhoneCode = ""
            dump(error)
        }
    }
}

#Preview {
    SignInFactorTwoPhoneCodeView(factor: .mock)
        .environment(AuthView.Config())
        .environment(ClerkUIState())
        .environment(ClerkTheme.clerkDefault)
}

#endif
