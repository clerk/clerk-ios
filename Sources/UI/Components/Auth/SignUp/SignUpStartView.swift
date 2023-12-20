//
//  SignUpStartView.swift
//
//
//  Created by Mike Pitre on 10/16/23.
//

#if canImport(UIKit)

import SwiftUI
import Clerk

struct SignUpStartView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    
    private var signUp: SignUp {
        clerk.client.signUp
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                
                HeaderView(
                    title: "Create your account",
                    subtitle: "Welcome! Please fill in the details to get started."
                )
                .padding(.bottom, 32)
                
                SignUpSocialProvidersView()
                    .onSuccess { dismiss() }
                
                TextDivider(text: "or")
                    .padding(.vertical, 24)

                SignUpFormView()
                    .padding(.bottom, 32)
                
                HStack(spacing: 4) {
                    Text("Already have an account?")
                        .font(.footnote)
                        .foregroundStyle(clerkTheme.colors.gray500)
                    Button {
                        clerkUIState.authIsPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                            clerkUIState.presentedAuthStep = .signInStart
                        })
                    } label: {
                        Text("Sign In")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.gray700)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 32)
            .background(.background)
        }
    }
}

#Preview {
    SignUpStartView()
        .environmentObject(Clerk.mock)
}

#endif
