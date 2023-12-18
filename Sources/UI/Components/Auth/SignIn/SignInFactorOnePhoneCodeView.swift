//
//  SignInFactorOnePhoneCodeView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignInFactorOnePhoneCodeView: View {
    @EnvironmentObject private var clerk: Clerk
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
                
                VerificationCodeView(
                    code: $code,
                    title: "Check your phone",
                    subtitle: "Enter the verification code sent to your phone number",
                    safeIdentifier: signIn.currentFactor?.safeIdentifier ?? signIn.identifier,
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
                .onUseAlernateMethod {
                    clerkUIState.presentedAuthStep = .signInStart
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
        .safeAreaInset(edge: .bottom) {
            SecuredByClerkView()
                .padding()
                .frame(maxWidth: .infinity)
                .background()
        }
    }
    
    private func prepare() async {
        do {
            try await signIn.prepareFirstFactor(.phoneCode)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            try await signIn.attemptFirstFactor(.phoneCode(code: code))
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
}

#Preview {
    SignInFactorOnePhoneCodeView()
        .environmentObject(Clerk.mock)
}

#endif
