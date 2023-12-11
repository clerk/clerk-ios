//
//  SignInFactorOneEmailCodeView.swift
//
//
//  Created by Mike Pitre on 11/2/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignInFactorOneEmailCodeView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    
    @State private var code: String = ""
    @State private var errorWrapper: ErrorWrapper?
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    var body: some View {
        ScrollView {
            VerificationCodeView(
                code: $code,
                title: "Check your email",
                subtitle: "to continue to \(clerk.environment.displayConfig.applicationName)",
                formTitle: "Verification code",
                formSubtitle: "Enter the verification code sent to your email address",
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
                await prepare()
            }
        }
    }
    
    private func prepare() async {
        do {
            guard let emailAddressId = signIn.supportedFirstFactors.first(where: { $0.verificationStrategy == .emailCode })?.emailAddressId else {
                throw ClerkClientError(message: "Unable to find an email address id for this verification strategy.")
            }
            try await signIn.prepareFirstFactor(.emailCode(emailAddressId: emailAddressId))
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            try await signIn.attemptFirstFactor(.emailCode(code: code))
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
}

#Preview {
    SignInFactorOneEmailCodeView()
        .environmentObject(Clerk.mock)
}

#endif
