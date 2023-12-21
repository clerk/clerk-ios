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
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .padding(.vertical)
        }
    }
}

#Preview {
    SignInStartView()
        .environmentObject(Clerk.mock)
}

#endif
