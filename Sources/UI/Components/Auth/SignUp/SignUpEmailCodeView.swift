//
//  SignUpEmailCodeView.swift
//
//
//  Created by Mike Pitre on 11/1/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk
import Factory

struct SignUpEmailCodeView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    
    @State private var code: String = ""
    
    private var signUp: SignUp {
        clerk.client.signUp
    }
    
    var body: some View {
        ScrollView {
            VerificationCodeView(
                code: $code,
                title: "Verify your email",
                subtitle: "to continue to \(clerk.environment.displayConfig.applicationName)",
                formTitle: "Verification code",
                formSubtitle: "Enter the verification code sent to your email address",
                safeIdentifier: signUp.emailAddress
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
        let emailVerification = signUp.verifications.first(where: { $0.key == "email_address" })?.value
        if signUp.status == nil || emailVerification?.status == .verified {
            return
        }
        
        do {
            try await signUp.prepareVerification(.emailCode)
        } catch {
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            try await signUp.attemptVerification(.emailCode(code: code))
        } catch {
            dump(error)
        }
    }
}

#Preview {
    let _ = Container.shared.clerk.register { Clerk.mock }
    return SignUpEmailCodeView()
        .environmentObject(Clerk.mock)
        .environmentObject(ClerkUIState())
}

#endif
