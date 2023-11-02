//
//  SignUpPhoneCodeView.swift
//
//
//  Created by Mike Pitre on 11/1/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import Factory

struct SignUpPhoneCodeView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    
    @State private var otpCode: String = ""
    
    private var signUp: SignUp {
        clerk.client.signUp
    }
    
    var body: some View {
        ScrollView {
            VerificationCodeView(
                otpCode: $otpCode,
                title: "Verify your phone number",
                subtitle: "to continue to \(clerk.environment.displayConfig.applicationName)",
                formTitle: "Verification code",
                formSubtitle: "Enter the verification code sent to your phone number",
                safeIdentifier: signUp.phoneNumber
            )
            .onIdentityPreviewTapped {
                clerkUIState.presentedAuthStep = .signUpStart
            }
            .onCodeEntry {
                await attempt()
            }
            .onResend {
                await prepare()
            }
            .onUseAlernateMethod {
                clerkUIState.presentedAuthStep = .signUpStart
            }
            .task {
                await prepare()
            }
        }
    }
    
    private func prepare() async {
        do {
            let signUpVerification = signUp.verifications.first(where: { $0.key == "phone_number" })?.value
            if signUp.status == nil || signUpVerification?.status == .verified {
                return
            }
            
            try await signUp.prepareVerification(.phoneCode)
        } catch {
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            try await signUp.attemptVerification(.phoneCode(code: otpCode))
        } catch {
            dump(error)
        }
    }
}

#Preview {
    let _ = Container.shared.clerk.register { Clerk.mock } 
    return SignUpPhoneCodeView()
        .environmentObject(Clerk.mock)
        .environmentObject(ClerkUIState())
}

#endif
