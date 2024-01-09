//
//  SignInFactorOneUseAnotherMethodView.swift
//
//
//  Created by Mike Pitre on 12/21/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignInFactorOneUseAnotherMethodView: View {
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
                
                SignInFactorOneAlternativeMethodsView(currentStrategy: currentStrategy)
                    .padding(.bottom, 18)
                
                Button {
                    switch currentStrategy {
                    case .password:
                        clerkUIState.presentedAuthStep = .signInPassword
                    default:
                        if signIn.firstFactorHasBeenPrepared {
                            clerkUIState.presentedAuthStep = .signInFactorOneVerify
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
    SignInFactorOneUseAnotherMethodView(currentStrategy: .password)
        .environmentObject(Clerk.mock)
        .environmentObject(ClerkUIState())
}

#endif
