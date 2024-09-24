//
//  SignInFactorOneResetView.swift
//
//
//  Created by Mike Pitre on 12/18/23.
//

#if os(iOS)

import SwiftUI

struct SignInFactorOneResetView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @EnvironmentObject private var config: AuthView.Config
    @Environment(\.clerkTheme) private var clerkTheme
    @State private var errorWrapper: ErrorWrapper?
    
    let factor: SignInFactor
    
    private var signIn: SignIn? {
        clerk.client?.signIn
    }
        
    private var useEmailCodeStrategy: Bool {
        factor.strategyEnum == .resetPasswordEmailCode
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .frame(width: 32, height: 32)
                    .padding(.bottom, 24)
                
                VerificationCodeView(
                    code: $config.signInFactorOneResetCode,
                    title: "Reset your password",
                    subtitle: "First, enter the code sent to your \(useEmailCodeStrategy ? "email address" : "phone")",
                    safeIdentifier: factor.safeIdentifier,
                    profileImageUrl: signIn?.userData?.imageUrl
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
                    if signIn?.firstFactorHasBeenPrepared == false {
                        await prepare()
                    }
                }
                
                Button {
                    if let passwordFactor = signIn?.firstFactor(for: .password) {
                        clerkUIState.presentedAuthStep = .signInFactorOne(factor: passwordFactor)
                    } else {
                        clerkUIState.presentedAuthStep = .signInStart
                    }
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
            guard let prepareFirstFactorStrategy = factor.prepareFirstFactorStrategy else {
                throw ClerkClientError(message: "Unable to determine the reset password strategy for this account.")
            }
            
            try await signIn?.prepareFirstFactor(for: prepareFirstFactorStrategy)
            
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
    
    private func attempt() async {
        do {
            switch factor.strategyEnum {
                
            case .resetPasswordEmailCode:
                try await signIn?.attemptFirstFactor(
                    for: .resetPasswordEmailCode(code: config.signInFactorOneResetCode)
                )
                
            case .resetPasswordPhoneCode:
                try await signIn?.attemptFirstFactor(
                    for: .resetPasswordPhoneCode(code: config.signInFactorOneResetCode)
                )
                
            default:
                throw ClerkClientError(message: "Unable to determine the reset password strategy for this account.")
            }
            
            clerkUIState.setAuthStepToCurrentSignInStatus()
            
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            config.signInFactorOneResetCode = ""
            dump(error)
        }
    }
}

#Preview {
    SignInFactorOneResetView(factor: .mock)
}

#endif
