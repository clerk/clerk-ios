//
//  SignUpPhoneCodeView.swift
//
//
//  Created by Mike Pitre on 11/1/23.
//

#if canImport(UIKit)

import SwiftUI
import ClerkSDK
import Factory

struct SignUpPhoneCodeView: View {
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
                    title: "Verify your phone number",
                    subtitle: "Enter the verification code sent to your phone number",
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
        do {
            let signUpVerification = signUp.verifications.first(where: { $0.key == "phone_number" })?.value
            if signUp.status == nil || signUpVerification?.status == .verified {
                return
            }
            
            try await signUp.prepareVerification(.phoneCode)
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            try await signUp.attemptVerification(.phoneCode(code: code))
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            code = ""
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
