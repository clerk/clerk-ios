//
//  SignUpVerificationView.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignUpVerificationView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.clerkTheme) private var clerkTheme
    
    @State private var otpCode = ""
    @State private var isSubmittingOTPCode = false
    private let requiredOtpCodeLength = 6
    
    var body: some View {
        VStack(alignment: .leading, spacing: 30) {
            HStack(spacing: 6) {
                Image("clerk-logomark", bundle: .module)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20)
                Text("clerk")
                    .font(.title3.weight(.semibold))
            }
            .font(.title3.weight(.medium))
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Check your email")
                    .font(.title2.weight(.semibold))
                Text("to continue to \(clerk.environment.displayConfig.applicationName)")
                    .font(.subheadline.weight(.light))
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading) {
                Text("Verification code")
                    .font(.subheadline.weight(.medium))
                    .padding(.bottom, 8)
                
                Text("Enter the verification code sent to your email address")
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.footnote.weight(.light))
                    .foregroundStyle(.secondary)
                
                HStack(alignment: .lastTextBaseline, spacing: 20) {
                    OTPFieldView(otpCode: $otpCode)
                        .frame(maxWidth: 250)
                        .padding(.vertical)
                        .padding(.bottom)
                    
                    if isSubmittingOTPCode {
                        ProgressView()
                            .offset(y: 4)
                    }
                }
                .onChange(of: otpCode) { newValue in
                    if newValue.count == requiredOtpCodeLength {
                        Task {
                            await verifyAction()
                        }
                    }
                }
                
                AsyncButton(options: [.disableButton], action: {
                    await prepareVerification()
                }, label: {
                    Text("Didn't recieve a code? Resend")
                        .font(.subheadline)
                        .foregroundStyle(clerkTheme.colors.primary)
                })
            }
            
            AsyncButton(action: {
                clerkUIState.presentedAuthStep = .signUpCreate
            }, label: {
                Text("Use another method")
                    .font(.subheadline)
                    .foregroundStyle(clerkTheme.colors.primary)
            })
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(30)
        .background(.background)
    }
    
    private func prepareVerification() async {
        do {
            try await clerk
                .client
                .signUp
                .prepareVerification(.init(
                    strategy: .emailCode
                ))
        } catch {
            dump(error)
        }
    }
    
    private func verifyAction() async {
        KeyboardHelpers.dismissKeyboard()
        isSubmittingOTPCode = true
        
        do {
            try await clerk
                .client
                .signUp
                .attemptVerification(.init(
                    strategy: .emailCode,
                    code: otpCode
                ))
            
            clerkUIState.authIsPresented = false
        } catch {
            dump(error)
            isSubmittingOTPCode = false
        }
    }
}

#Preview {
    SignUpVerificationView()
}

#endif
