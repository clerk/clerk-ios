//
//  SignInFactorOneEmailCodeView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if os(iOS)

import SwiftUI
import Clerk

struct SignInFactorOneEmailCodeView: View {
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
                    code: $config.signInFactorOnePhoneCode,
                    title: "Check your email",
                    subtitle: "Enter the verification code sent to your email address",
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
            guard let emailAddressId = factor.emailAddressId else { return }
            try await signIn?.prepareFirstFactor(for: .emailCode(emailAddressId: emailAddressId))
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            try await signIn?.attemptFirstFactor(
                for: .emailCode(code: config.signInFactorOnePhoneCode)
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
    SignInFactorOneEmailCodeView(factor: .mock)
        .environment(AuthView.Config())
        .environment(ClerkUIState())
        .environment(ClerkTheme.clerkDefault)
}

#endif
