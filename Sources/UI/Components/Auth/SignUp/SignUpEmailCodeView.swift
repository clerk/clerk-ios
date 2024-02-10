//
//  SignUpEmailCodeView.swift
//
//
//  Created by Mike Pitre on 11/1/23.
//

#if canImport(UIKit)

import SwiftUI

struct SignUpEmailCodeView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    
    @State private var code: String = ""
    @State private var errorWrapper: ErrorWrapper?
    
    private var signUp: SignUp {
        clerk.client.signUp
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .padding(.bottom, 24)
                
                VerificationCodeView(
                    code: $code,
                    title: "Verify your email",
                    subtitle: "Enter the verification code sent to your email address",
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
                .clerkErrorPresenting($errorWrapper)
                .task {
                    await prepare()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 32)
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
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            try await signUp.attemptVerification(.emailCode(code: code))
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            code = ""
            dump(error)
        }
    }
}

#Preview {
    return SignUpEmailCodeView()
        .environmentObject(Clerk.shared)
        .environmentObject(ClerkUIState())
}

#endif
