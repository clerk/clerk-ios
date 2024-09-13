//
//  SignInFactorOnePhoneCodeView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if os(iOS)

import SwiftUI

struct SignInFactorOnePhoneCodeView: View {
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
                    code: $config.signInFactorOnePhoneCode,
                    title: "Check your phone",
                    subtitle: "Enter the verification code sent to your phone number",
                    safeIdentifier: signIn.currentFirstFactor?.safeIdentifier ?? signIn.identifier,
                    profileImageUrl: signIn.userData?.imageUrl
                )
                .onIdentityPreviewTapped {
                    clerkUIState.presentedAuthStep = .signInStart
                }
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
                    clerkUIState.presentedAuthStep = .signInFactorOneUseAnotherMethod(
                        signIn: signIn,
                        currentFactor: signIn.firstFactor(for: .phoneCode)
                    )
                }
                .clerkErrorPresenting($errorWrapper)
                .task {
                    if !signIn.firstFactorHasBeenPrepared {
                        await prepare()
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 32)
        }
    }
    
    private func prepare() async {
        do {
            try await signIn.prepareFirstFactor(for: .phoneCode)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            let attemptedSignIn = try await signIn.attemptFirstFactor(
                for: .phoneCode(code: config.signInFactorOnePhoneCode)
            )
            clerkUIState.setAuthStepToCurrentStatus(for: attemptedSignIn)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            config.signInFactorOnePhoneCode = ""
            dump(error)
        }
    }
}

#Preview {
    SignInFactorOnePhoneCodeView(signIn: .mock)
}

#endif
