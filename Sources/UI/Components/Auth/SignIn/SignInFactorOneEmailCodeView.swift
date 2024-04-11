//
//  SignInFactorOneEmailCodeView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if os(iOS)

import SwiftUI

struct SignInFactorOneEmailCodeView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    
    @State private var code: String = ""
    @State private var errorWrapper: ErrorWrapper?
    
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
                    code: $code,
                    title: "Check your email",
                    subtitle: "Enter the verification code sent to your email address",
                    safeIdentifier: signIn?.currentFirstFactor?.safeIdentifier ?? signIn?.identifier,
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
                    clerkUIState.presentedAuthStep = .signInFactorOneUseAnotherMethod(signIn?.firstFactor(for: .emailCode))
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
            try await signIn?.prepareFirstFactor(for: .emailCode)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            try await signIn?.attemptFirstFactor(for: .emailCode(code: code))
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            code = ""
            dump(error)
        }
    }
}

#Preview {
    SignInFactorOneEmailCodeView()
}

#endif
