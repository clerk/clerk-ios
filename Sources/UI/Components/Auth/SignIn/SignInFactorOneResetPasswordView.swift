//
//  SignInResetPasswordView.swift
//
//
//  Created by Mike Pitre on 12/18/23.
//

import SwiftUI

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignInFactorOneResetPasswordView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    
    @State private var code: String = ""
    @State private var errorWrapper: ErrorWrapper?
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
        
    private var useEmailCodeStrategy: Bool {
        signIn.firstFactorVerification?.verificationStrategy == .resetPasswordEmailCode
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                
                VerificationCodeView(
                    code: $code,
                    title: "Reset your password",
                    subtitle: "First, enter the code sent to your \(useEmailCodeStrategy ? "email address" : "phone")",
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
                
                Button {
                    clerkUIState.presentedAuthStep = .signInForgotPassword
                } label: {
                    Text("Back to sign in")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(clerkTheme.colors.gray700)
                        .frame(minHeight: ClerkStyleConstants.textMinHeight)
                }
            }
            .padding()
            .padding(.vertical)
        }
        .clerkErrorPresenting($errorWrapper)
    }
    
    private func prepare() async {
        do {
            switch signIn.firstFactorVerification?.verificationStrategy {
                
            case .resetPasswordEmailCode:
                try await signIn.prepareFirstFactor(.resetPasswordEmailCode)
                
            case .resetPasswordPhoneCode:
                try await signIn.prepareFirstFactor(.resetPasswordPhoneCode)
                
            default:
                throw ClerkClientError(message: "Unable to determine the reset password strategy for this account.")
            }
            
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            switch signIn.currentFactor?.verificationStrategy {
                
            case .resetPasswordEmailCode:
                try await signIn.attemptFirstFactor(.resetEmailCode(code: code))
                
            case .resetPasswordPhoneCode:
                try await signIn.attemptFirstFactor(.resetPhoneCode(code: code))
                
            default:
                throw ClerkClientError(message: "Unable to determine the reset password strategy for this account.")
            }
            
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
}

#Preview {
    SignInFactorOneResetPasswordView()
        .environmentObject(Clerk.mock)
}

#endif
