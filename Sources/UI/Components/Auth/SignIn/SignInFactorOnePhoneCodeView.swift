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
            VerificationCodeView(
                code: $code,
                title: "Check your phone",
                subtitle: "to continue to \(clerk.environment.displayConfig.applicationName)",
                formTitle: "Verification code",
                formSubtitle: "Enter the verification code sent to your phone number",
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
            guard let phoneNumberId = signIn.supportedFirstFactors.first(where: { $0.verificationStrategy == .phoneCode })?.phoneNumberId else {
                throw ClerkClientError(message: "Unable to find an phone number id for this verification strategy.")
            }
            try await signIn.prepareFirstFactor(.phoneCode(phoneNumberId: phoneNumberId))
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
