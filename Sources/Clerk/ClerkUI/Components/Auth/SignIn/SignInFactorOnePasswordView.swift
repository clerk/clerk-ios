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
  @Environment(\.authState) private var authState
  @FocusState private var isFocused: Bool
  @State private var error: Error?

  var signIn: SignIn? {
    clerk.client?.signIn
  }
  
  let factor: Factor

  var body: some View {
    @Bindable var authState = authState

    ScrollView {
      VStack(spacing: 0) {
        AppLogoView()
          .frame(maxHeight: 44)
          .padding(.bottom, 24)

        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Enter password")
          HeaderView(style: .subtitle, text: "Enter the password for your account")

          if let identifier = signIn?.identifier {
            Button {
              authState.step = .signInStart
            } label: {
              IdentityPreviewView(label: identifier)
            }
            .buttonStyle(.secondary(config: .init(size: .small)))
          }
        }
        .padding(.bottom, 32)

        VStack(spacing: 24) {

          ClerkTextField(
            "Enter your password",
            text: $authState.password,
            isSecure: true
          )
          .textContentType(.password)
          .textInputAutocapitalization(.never)
          .focused($isFocused)
          .onFirstAppear {
            isFocused = true
          }

          AsyncButton {
            await submitPassword()
          } label: { isRunning in
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
          .buttonStyle(.primary())
          .disabled(authState.password.isEmpty)
        }
        .padding(.bottom, 16)

        Button {
          authState.step = .signInFactorOneUseAnotherMethod(currentFactor: factor)
        } label: {
          Text("Use another method", bundle: .module)
            .font(theme.fonts.subheadline)
            .foregroundStyle(theme.colors.primary)
            .frame(minHeight: 20)
        }
        .buttonStyle(
          .primary(
            config: .init(
              emphasis: .none,
              size: .small
            )
          )
        )
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 32)
    }
    .background(theme.colors.background)
    .scrollBounceBehavior(.basedOnSize)
  }
}

extension SignInFactorOnePasswordView {

  func submitPassword() async {
    isFocused = false
    
    do {
      guard let signIn else {
        authState.step = .signInStart
        return
      }

      try await signIn.attemptFirstFactor(
        strategy: .password(password: authState.password)
      )

      authState.setToStepForStatus(signIn: signIn)
    } catch {
      self.error = error
    }
  }

}

#Preview {
  SignInFactorOnePasswordView(factor: .mockPassword)
    .environment(\.clerk, .mock)
}

#Preview("Localized") {
  SignInFactorOnePasswordView(factor: .mockPassword)
    .environment(\.clerk, .mock)
    .environment(\.locale, .init(identifier: "es"))
}
