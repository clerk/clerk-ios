//
//  SignInFactorOnePasswordView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/17/25.
//

import SwiftUI

struct SignInFactorOnePasswordView: View {
  @Environment(\.clerk) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.signInViewState) private var state

  var body: some View {
    @Bindable var state = state

    ScrollView {
      VStack(spacing: 0) {
        AppLogoView()
          .frame(maxHeight: 44)
          .padding(.bottom, 24)

        Text("Enter password", bundle: .module)
          .font(theme.fonts.title)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
          .frame(minHeight: 28)
          .padding(.bottom, 8)
          .foregroundStyle(theme.colors.text)

        Text("Enter the password associated with your account", bundle: .module)
          .font(theme.fonts.subheadline)
          .multilineTextAlignment(.center)
          .frame(minHeight: 18)
          .foregroundStyle(theme.colors.textSecondary)
          .padding(.bottom, 32)

        ClerkTextField(
          "Enter your password",
          text: $state.identifier,
          isSecure: true
        )
        .textContentType(.emailAddress)
        .textInputAutocapitalization(.never)
        .padding(.bottom, 24)

        AsyncButton(
          action: {
            // sign in with password
          },
          label: { isRunning in
            HStack(spacing: 4) {
              Text("Continue", bundle: .module)
              Image("triangle-right", bundle: .module)
                .foregroundStyle(theme.colors.textOnPrimaryBackground)
                .opacity(0.6)
            }
            .overlayProgressView(isActive: isRunning) {
              SpinnerView(color: theme.colors.textOnPrimaryBackground)
            }
          }
        )
        .buttonStyle(.primary())
        .padding(.bottom, 16)
        
        Button {
          // use another method
        } label: {
          Text("Use another method", bundle: .module)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.primary)
            .frame(minHeight: 22)
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding([.horizontal, .bottom], 16)
      .padding(.top, 32)
    }
    .background(theme.colors.background)
    .scrollBounceBehavior(.basedOnSize)
  }
}

#Preview {
  SignInFactorOnePasswordView()
}

#Preview("Spanish") {
  SignInFactorOnePasswordView()
    .environment(\.locale, .init(identifier: "es"))
}
