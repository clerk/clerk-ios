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
  @Environment(\.authState) private var authState

  @State private var email: String = ""
  @State private var error: Error?

  var signInText: Text {
    if let appName = clerk.environment.displayConfig?.applicationName {
      return Text("Continue to \(appName)", bundle: .module)
    } else {
      return Text("Continue", bundle: .module)
    }
  }

  var body: some View {
    @Bindable var authState = authState

    ScrollView {
      VStack(spacing: 0) {
        AppLogoView()
          .frame(maxHeight: 44)
          .padding(.bottom, 24)

        VStack(spacing: 8) {
          signInText
            .font(theme.fonts.title)
            .fontWeight(.bold)
            .multilineTextAlignment(.center)
            .frame(minHeight: 28)
            .foregroundStyle(theme.colors.text)

          Text("Welcome! Sign in to continue", bundle: .module)
            .font(theme.fonts.subheadline)
            .multilineTextAlignment(.center)
            .frame(minHeight: 18)
            .foregroundStyle(theme.colors.textSecondary)
        }
        .padding(.bottom, 32)

        VStack(spacing: 24) {
          ClerkTextField(
            "email, username or mobile number",
            text: $authState.identifier
          )
          .textContentType(.emailAddress)
          .textInputAutocapitalization(.never)

          AsyncButton(
            action: {
              await createSignIn()
            },
            label: { isRunning in
              HStack(spacing: 4) {
                Text("Continue", bundle: .module)
                Image("triangle-right", bundle: .module)
                  .foregroundStyle(theme.colors.textOnPrimaryBackground)
                  .opacity(0.6)
              }
              .frame(maxWidth: .infinity)
              .overlayProgressView(isActive: isRunning) {
                SpinnerView(color: theme.colors.textOnPrimaryBackground)
              }
            }
          )
          .buttonStyle(.primary())
          .disabled(authState.identifier.isEmpty)

          TextDivider(string: "or")

          SocialButtonGrid(
            providers: clerk.environment.authenticatableSocialProviders
          )
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 32)
    }
    .presentationBackground(theme.colors.background)
    .scrollBounceBehavior(.basedOnSize)
  }
}

extension SignInStartView {
  
  func createSignIn() async {
    do {
      let signIn = try await SignIn.create(
        strategy: .identifier(authState.identifier)
      )
      authState.setToStepForStatus(signIn: signIn)
    } catch {
      self.error = error
    }
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

#Preview("Localized") {
  SignInStartView()
    .environment(\.clerk, .mock)
    .environment(\.locale, .init(identifier: "es"))
}
