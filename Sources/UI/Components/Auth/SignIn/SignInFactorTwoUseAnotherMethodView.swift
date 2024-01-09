//
//  SignInFactorTwoUseAnotherMethodView.swift
//
//
//  Created by Mike Pitre on 1/8/24.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignInFactorTwoUseAnotherMethodView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    let currentStrategy: Strategy
    
    public var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .padding(.bottom, 24)
                
                HeaderView(
                    title: "Use another method",
                    subtitle: "Facing issues? You can use any of these methods to sign in."
                )
                .padding(.bottom, 32)
                
                SignInFactorTwoAlternativeMethodsView(currentStrategy: currentStrategy)
                    .padding(.bottom, 18)
                
                Button {
                    switch currentStrategy {
                    case .backupCode:
                        clerkUIState.presentedAuthStep = .signInFactorTwoBackupCode
                    default:
                        if signIn.secondFactorHasBeenPrepared {
                            clerkUIState.presentedAuthStep = .signInFactorTwoVerify
                        } else {
                            clerkUIState.presentedAuthStep = .signInStart
                        }
                    }
                } label: {
                    Text("Back to previous method")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(clerkTheme.colors.gray700)
                        .frame(minHeight: ClerkStyleConstants.textMinHeight)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .padding(.vertical)
        }
    }
}

#Preview {
    SignInFactorTwoUseAnotherMethodView(currentStrategy: .totp)
}

#endif
