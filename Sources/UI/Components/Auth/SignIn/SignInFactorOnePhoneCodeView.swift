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
    
    let factor: SignInFactor
    
    private var signIn: SignIn? {
        clerk.client?.signIn
    }
    
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
                    safeIdentifier: factor.safeIdentifier,
                    profileImageUrl: signIn?.userData?.imageUrl
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
                        currentFactor: factor
                    )
                }
                .clerkErrorPresenting($errorWrapper)
                .task {
                    if signIn?.firstFactorHasBeenPrepared == false {
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
            guard let prepareFirstFactorStrategy = factor.prepareFirstFactorStrategy else {
                throw ClerkClientError(message: "Unable to determine the first factor strategy to prepare.")
            }
            
            try await signIn?.prepareFirstFactor(for: prepareFirstFactorStrategy)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            try await signIn?.attemptFirstFactor(
                for: .phoneCode(code: config.signInFactorOnePhoneCode)
            )
            clerkUIState.setAuthStepToCurrentSignInStatus()
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            config.signInFactorOnePhoneCode = ""
            dump(error)
        }
    }
}

#Preview {
    SignInFactorOnePhoneCodeView(factor: .mock)
}

#endif
