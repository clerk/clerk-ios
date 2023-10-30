//
//  SignInFirstFactorView.swift
//
//
//  Created by Mike Pitre on 10/10/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignInFirstFactorView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.clerkTheme) private var clerkTheme
    
    @State private var otpCode = ""
    @State private var isSubmittingOTPCode = false
    private let requiredOtpCodeLength = 6
    
    @State private var firstFactorStrategy: SignIn.PrepareStrategy = .emailCode
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    private var titleString: String {
        switch firstFactorStrategy {
        case .emailCode:
            return "Check your email"
        case .phoneCode:
            return "Verify your phone"
        }
    }
    
    private var instructionsString: String {
        switch firstFactorStrategy {
        case .emailCode:
            return "Enter the verification code sent to your email address"
        case .phoneCode:
            return "Enter the verification code sent to your phone number"
        }
    }
    
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
                Text(titleString)
                    .font(.title2.weight(.semibold))
                Text("to continue to \(clerk.environment.displayConfig.applicationName)")
                    .font(.subheadline.weight(.light))
                    .foregroundStyle(.secondary)
            }
            
            IdentityPreviewView(
                imageUrl: signIn.userData?.imageUrl ?? "",
                label: signIn.firstFactor?.safeIdentifier ?? "",
                action: {
                    clerkUIState.presentedAuthStep = .signInCreate
                }
            )
            
            VStack(alignment: .leading) {
                Text("Verification code")
                    .font(.subheadline.weight(.medium))
                    .padding(.bottom, 8)
                
                Text(instructionsString)
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
                            await attemptFirstFactor()
                        }
                    }
                }
                
                AsyncButton(options: [.disableButton], action: {
                    await prepareFirstFactor()
                }, label: {
                    Text("Didn't recieve a code? Resend")
                        .font(.subheadline)
                        .foregroundStyle(clerkTheme.colors.primary)
                })
            }
            
            AsyncButton(action: {
                clerkUIState.presentedAuthStep = .signInCreate
            }, label: {
                Text("Use another method")
                    .font(.subheadline)
                    .foregroundStyle(clerkTheme.colors.primary)
            })
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(30)
        .background(.background)
        .task {
            self.firstFactorStrategy = signIn.firstFactorPrepareStrategy ?? .emailCode
        }
    }
    
    private func prepareFirstFactor() async {
        do {
            switch signIn.firstFactorPrepareStrategy {
            case .emailCode:
                try await signIn.prepareFirstFactor(.emailCode)
            case .phoneCode:
                try await signIn.prepareFirstFactor(.phoneCode)
            default:
                throw ClerkClientError(message: "Unable to prepare verification.")
            }
            
        } catch {
            dump(error)
        }
    }
    
    private func attemptFirstFactor() async {
        isSubmittingOTPCode = true
        KeyboardHelpers.dismissKeyboard()
        
        do {
            switch signIn.firstFactorPrepareStrategy {
            case .emailCode:
                try await signIn.attemptFirstFactor(.emailCode(code: otpCode))
            case .phoneCode:
                try await signIn.attemptFirstFactor(.phoneCode(code: otpCode))
            default:
                throw ClerkClientError(message: "Unable to attempt verification.")
            }
            
            clerkUIState.authIsPresented = false
        } catch {
            dump(error)
            isSubmittingOTPCode = false
        }
    }
}

#Preview {
    SignInFirstFactorView()
        .environmentObject(Clerk.mock)
}

#endif
