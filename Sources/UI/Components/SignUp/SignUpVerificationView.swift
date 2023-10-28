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
    
    @State private var strategy: SignUp.PrepareStrategy = .emailCode
    
    private var signUp: SignUp {
        clerk.client.signUp
    }
    
    private var titleString: String {
        switch strategy {
        case .emailLink, .emailCode:
            return "Verify your email"
        case .phoneCode:
            return "Verify your phone number"
        }
    }
    
    private var identityPreviewString: String {
        switch strategy {
        case .emailLink, .emailCode:
            return signUp.emailAddress ?? ""
        case .phoneCode:
            return signUp.phoneNumber ?? ""
        }
    }
    
    private var strategyTitleString: String {
        switch strategy {
        case .emailLink:
            return "Email link"
        case .emailCode, .phoneCode:
            return "Verification code"
        }
    }
    
    private var strategySubtitleString: String {
        switch strategy {
        case .emailLink:
            return "Check your email for you verification link"
        case .emailCode:
            return "Enter the verification code sent to your email address"
        case .phoneCode:
            return "Enter the verification code sent to your phone number"
        }
    }
    
    private var displaysOTPCodeField: Bool {
        switch strategy {
        case .emailLink:
            return false
        case .emailCode, .phoneCode:
            return true
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
                imageUrl: nil,
                label: identityPreviewString,
                action: {
                    clerkUIState.presentedAuthStep = .signUpCreate
                }
            )
            
            VStack(alignment: .leading) {
                Text(strategyTitleString)
                    .font(.subheadline.weight(.medium))
                    .padding(.bottom, 8)
                
                Text(strategySubtitleString)
                    .fixedSize(horizontal: false, vertical: true)
                    .font(.footnote.weight(.light))
                    .foregroundStyle(.secondary)
                
                if displaysOTPCodeField {
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
                                switch strategy {
                                case .emailCode:
                                    await verifyAction(strategy: .emailCode(code: otpCode))
                                case .phoneCode:
                                    await verifyAction(strategy: .phoneCode(code: otpCode))
                                default:
                                    break
                                }
                            }
                        }
                    }
                }
                
                AsyncButton(options: [.disableButton], action: {
                    await prepareVerification(strategy: strategy)
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
        .id(strategy)
        .transition(.offset(y: 50).combined(with: .opacity))
        .animation(.bouncy, value: strategy)
        .task {
            switch signUp.nextStrategyToVerify {
            case .emailCode:
                self.strategy = .emailCode
            case .emailLink:
                self.strategy = .emailLink
            case .phoneCode:
                self.strategy = .phoneCode
            default:
                clerkUIState.authIsPresented = false
            }
        }
    }
    
    private func prepareVerification(strategy: SignUp.PrepareStrategy) async {
        do {
            try await signUp.prepareVerification(strategy)
        } catch {
            dump(error)
        }
    }
    
    private func verifyAction(strategy: SignUp.AttemptStrategy) async {
        KeyboardHelpers.dismissKeyboard()
        isSubmittingOTPCode = true
        
        do {
            try await signUp.attemptVerification(strategy)
            
            otpCode = ""
            isSubmittingOTPCode = false

            switch signUp.nextStrategyToVerify {
            case .emailCode:
                self.strategy = .emailCode
                await prepareVerification(strategy: .emailCode)
            case .emailLink:
                self.strategy = .emailLink
                await prepareVerification(strategy: .emailLink)
            case .phoneCode:
                self.strategy = .phoneCode
                await prepareVerification(strategy: .phoneCode)
            default:
                clerkUIState.authIsPresented = false
            }
        } catch {
            dump(error)
            isSubmittingOTPCode = false
            otpCode = ""
        }
        
    }
}

#Preview {
    SignUpVerificationView()
        .environmentObject(Clerk.mock)
        .environmentObject(ClerkUIState())
}

#endif
