//
//  SignInFactorTwoUseAnotherMethodView.swift
//
//
//  Created by Mike Pitre on 1/8/24.
//

#if os(iOS)

import SwiftUI

struct SignInFactorTwoUseAnotherMethodView: View {
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
                .padding(.bottom, 32)
                
                SignInFactorTwoAlternativeMethodsView(signIn: signIn, currentFactor: currentFactor)
                    .padding(.bottom, 18)
                
                Button {
                    clerkUIState.presentedAuthStep = .signInFactorTwo(signIn: signIn, factor: currentFactor)
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
    SignInFactorTwoUseAnotherMethodView(signIn: .mock, currentFactor: .mock)
}

#endif
