//
//  SignInFactorOneUseAnotherMethodView.swift
//
//
//  Created by Mike Pitre on 12/21/23.
//

#if canImport(UIKit)

import SwiftUI

struct SignInFactorOneUseAnotherMethodView: View {
    @EnvironmentObject private var clerk: Clerk
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    
    private var signIn: SignIn {
        clerk.client.signIn
    }
    
    let currentFactor: SignInFactor?
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .padding(.bottom, 24)
                
                HeaderView(
                    title: "Use another method",
                    subtitle: "Facing issues? You can use any of these methods to sign in."
                )
                .padding(.bottom, 32)
                
                SignInFactorOneAlternativeMethodsView(currentFactor: currentFactor)
                    .padding(.bottom, 18)
                
                Button {
                    clerkUIState.presentedAuthStep = .signInFactorOne(currentFactor)
                } label: {
                    Text("Back to previous method")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(clerkTheme.colors.textSecondary)
                        .frame(minHeight: 18)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .padding(.vertical)
        }
    }
}

#Preview {
    SignInFactorOneUseAnotherMethodView(currentFactor: nil)
        .environmentObject(Clerk.shared)
        .environmentObject(ClerkUIState())
}

#endif
