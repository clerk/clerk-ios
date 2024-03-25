//
//  SignInFactorTwoPhoneCodeView.swift
//
//
//  Created by Mike Pitre on 1/8/24.
//

#if canImport(UIKit)

import SwiftUI

struct SignInFactorTwoPhoneCodeView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    
    @State private var code: String = ""
    @State private var errorWrapper: ErrorWrapper?
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .frame(width: 32, height: 32)
                    .padding(.bottom, 24)
                
                VerificationCodeView(
                    code: $code,
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
                    clerkUIState.presentedAuthStep = .signInFactorTwoUseAnotherMethod(signIn.secondFactor(for: .phoneCode))
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
            try await signIn.attemptSecondFactor(for: .phoneCode(code: code))
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            code = ""
            dump(error)
        }
    }
}

#Preview {
    SignInFactorTwoPhoneCodeView()
}

#endif
