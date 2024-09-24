//
//  SignInFactorTwoBackupCodeView.swift
//
//
//  Created by Mike Pitre on 1/8/24.
//

#if os(iOS)

import SwiftUI

struct SignInFactorTwoBackupCodeView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @EnvironmentObject private var config: AuthView.Config
    @Environment(\.clerkTheme) private var clerkTheme
    @State private var errorWrapper: ErrorWrapper?
    
    let factor: SignInFactor
    
    private var signIn: SignIn? {
        clerk.client?.signIn
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .frame(width: 32, height: 32)
                    .padding(.bottom, 24)
                
                HeaderView(
                    title: "Enter a backup code",
                    subtitle: "Your backup code is the one you got when setting up two-step authentication."
                )
                .padding(.bottom, 32)
                
                VStack(alignment: .leading) {
                    HStack {
                        Text("Backup code")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.textPrimary)
                        Spacer()
                    }
                    CustomTextField(text: $config.signInFactorTwoBackupCode)
                }
                .padding(.bottom, 32)
                
                AsyncButton {
                    //
                } label: {
                    Text("Continue")
                        .clerkStandardButtonPadding()
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(ClerkPrimaryButtonStyle())
                .padding(.bottom, 18)
                
                AsyncButton {
                    clerkUIState.presentedAuthStep = .signInFactorTwoUseAnotherMethod(
                        currentFactor: factor
                    )
                } label: {
                    Text("Use another method")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(clerkTheme.colors.textSecondary)
                }

            }
            .padding(.horizontal)
            .padding(.vertical, 32)
            .clerkErrorPresenting($errorWrapper)
        }
    }
    
    private func attempt() async {
        do {
            try await signIn?.attemptSecondFactor(
                for: .backupCode(code: config.signInFactorTwoBackupCode)
            )
            
            clerkUIState.setAuthStepToCurrentSignInStatus()
        } catch {
            errorWrapper = ErrorWrapper(error: error)
            dump(error)
        }
    }
}

#Preview {
    SignInFactorTwoBackupCodeView(factor: .mock)
}

#endif
