//
//  SignInStartView.swift
//
//
//  Created by Mike Pitre on 9/22/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignInStartView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    
    public var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                
                HeaderView(
                    title: "Sign in to \(clerk.environment.displayConfig.applicationName)",
                    subtitle: "Welcome back! Please sign in to continue"
                )
                .padding(.bottom, 32)
                
                SignInSocialProvidersView()
                    .onSuccess { dismiss() }
                
                TextDivider(text: "or")
                    .padding(.vertical, 24)
                
                SignInFormView()
                    .padding(.bottom, 32)
                                
                HStack(spacing: 4) {
                    Text("Don't have an account?")
                        .font(.footnote)
                        .foregroundStyle(clerkTheme.colors.gray500)
                    Button {
                        clerkUIState.authIsPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                            clerkUIState.presentedAuthStep = .signUpStart
                        })
                    } label: {
                        Text("Sign Up")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.gray700)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .padding(.vertical)
            .background(.background)
        }
        .safeAreaInset(edge: .bottom) {
            SecuredByClerkView()
                .padding()
                .frame(maxWidth: .infinity)
                .background()
        }
    }
}

#Preview {
    SignInStartView()
        .environmentObject(Clerk.mock)
}

#endif
