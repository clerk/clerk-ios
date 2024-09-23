//
//  SignInFactorOneUseAnotherMethodView.swift
//
//
//  Created by Mike Pitre on 12/21/23.
//

#if os(iOS)

import SwiftUI

struct SignInFactorOneUseAnotherMethodView: View {
    @ObservedObject private var clerk = Clerk.shared
    @EnvironmentObject private var clerkUIState: ClerkUIState
    @Environment(\.clerkTheme) private var clerkTheme
    @Environment(\.dismiss) private var dismiss
    
    let signIn: SignIn
    let currentFactor: SignInFactor?
    
    var body: some View {
        ScrollView {
            VStack(spacing: .zero) {
                OrgLogoView()
                    .frame(width: 32, height: 32)
                    .padding(.bottom, 24)
                
                HeaderView(
                    title: "Use another method",
                    subtitle: "Facing issues? You can use any of these methods to sign in."
                )
                .multilineTextAlignment(.center)
                .padding(.bottom, 32)
                
                SignInFactorOneAlternativeMethodsView(
                    signIn: signIn,
                    currentFactor: currentFactor
                )
                .padding(.bottom, 18)
                
                Button {
                    clerkUIState.presentedAuthStep = .signInFactorOne(signIn: signIn, factor: currentFactor)
                } label: {
                    Text("Back to previous method")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(clerkTheme.colors.textSecondary)
                        .frame(minHeight: 18)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .padding(.top, 30)
        }
    }
}

#Preview {
    SignInFactorOneUseAnotherMethodView(signIn: .mock, currentFactor: .mock)
        .environmentObject(ClerkUIState())
}

#endif
