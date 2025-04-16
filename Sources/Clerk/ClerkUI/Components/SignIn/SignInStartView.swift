//
//  SignInView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/9/25.
//

import Factory
import SwiftUI

struct SignInStartView: View {
  @Environment(\.clerk) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.signInViewState) private var state

  @State private var email: String = ""

  var signInText: Text {
    if let appName = clerk.environment.displayConfig?.applicationName {
      return Text("Sign in to \(appName)", bundle: .module)
    } else {
      return Text("Sign in", bundle: .module)
    }
  }

  var body: some View {
    @Bindable var state = state
    
    ScrollView {
      VStack(spacing: 0) {
        AppLogoView()
          .frame(maxHeight: 44)
          .padding(.bottom, 24)

        signInText
          .font(theme.fonts.title)
          .fontWeight(.bold)
          .multilineTextAlignment(.center)
          .frame(minHeight: 28)
          .padding(.bottom, 8)
          .foregroundStyle(theme.colors.text)

        Text("Welcome! Please sign in to continue", bundle: .module)
          .font(theme.fonts.subheadline)
          .multilineTextAlignment(.center)
          .frame(minHeight: 18)
          .foregroundStyle(theme.colors.textSecondary)
          .padding(.bottom, 32)

        ClerkTextField("Enter your email", text: $state.identifier)
          .textContentType(.emailAddress)
          .textInputAutocapitalization(.never)
          .padding(.bottom, 24)

        AsyncButton(
          action: {
            try! await Task.sleep(for: .seconds(1))
            state.flowStep = .firstFactor
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
        .buttonStyle(.primary)

        TextDivider(string: "or")
          .padding(.vertical, 24)

        SocialButtonGrid(
          providers: clerk.environment.authenticatableSocialProviders
        )
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
  SignInStartView()
    .environment(\.clerk, .mock)
}

#Preview("Clerk Theme") {
  SignInStartView()
    .environment(\.clerk, .mock)
    .environment(\.clerkTheme, .clerk)
}

#Preview("Spanish") {
  SignInStartView()
    .environment(\.clerk, .mock)
    .environment(\.locale, .init(identifier: "es"))
}
