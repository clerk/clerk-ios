//
//  SignInFactorOneResetView.swift
//
//
//  Created by Mike Pitre on 12/18/23.
//

#if canImport(UIKit)

import SwiftUI
import ClerkSDK

struct SignInFactorOneResetView: View {
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
                    .padding(.bottom, 24)
                
                VerificationCodeView(
                    code: $code,
                    title: "Reset your password",
                    subtitle: "First, enter the code sent to your \(useEmailCodeStrategy ? "email address" : "phone")",
                    safeIdentifier: signIn.currentFirstFactor?.safeIdentifier ?? signIn.identifier,
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
                .onContinueAction {
                    //
                }
                .task {
                    if !signIn.firstFactorHasBeenPrepared {
                        await prepare()
                    }
                }
                
                Button {
                    clerkUIState.presentedAuthStep = .signInFactorOne(signIn.firstFactor(for: .password))
                } label: {
                    Text("Back to sign in")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(clerkTheme.colors.textPrimary)
                        .frame(minHeight: 18)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 32)
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
            switch signIn.currentFirstFactor?.verificationStrategy {
                
            case .resetPasswordEmailCode:
                try await signIn.attemptFirstFactor(.resetEmailCode(code: code))
                
            case .resetPasswordPhoneCode:
                try await signIn.attemptFirstFactor(.resetPhoneCode(code: code))
                
            default:
                throw ClerkClientError(message: "Unable to determine the reset password strategy for this account.")
            }
            
            clerkUIState.presentedAuthStep = .signInResetPassword
            
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            code = ""
            dump(error)
        }
    }
}

#Preview {
    SignInFactorOneResetView()
        .environmentObject(Clerk.mock)
}

#endif
