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
            VStack(alignment: .leading, spacing: 30) {
                HeaderView(
                    title: "Create your account",
                    subtitle: "to continue to \(clerk.environment.displayConfig.applicationName)"
                )
                
                SignUpSocialProvidersView()
                    .onSuccess { dismiss() }
                
                OrDivider()
                
                SignUpFormView()
                
                HStack(spacing: 4) {
                    Text("Have an account?")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button {
                        clerkUIState.authIsPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: {
                            clerkUIState.presentedAuthStep = .signInStart
                        })
                    } label: {
                        Text("Sign In")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(clerkTheme.colors.primary)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text("Secured by ")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Image("clerk-logomark", bundle: .module)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16)
                            Text("clerk")
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }
                    
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .padding(.vertical)
            .background(.background)
        }
    }
}

#Preview {
    SignUpStartView()
        .environmentObject(Clerk.mock)
}

#endif
