//
//  SignInFactorOnePasswordView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkJSCore
import ClerkKit
import SwiftUI

struct SignInFactorOnePasswordView: View {
  @SwiftUI.Environment(ClerkKit.Clerk.self) private var clerk
  @SwiftUI.Environment(ClerkJSCore.Clerk.self) private var jsClerk
  @SwiftUI.Environment(\.clerkTheme) private var theme
  @SwiftUI.Environment(AuthNavigation.self) private var navigation
  @SwiftUI.Environment(AuthState.self) private var authState

  @FocusState private var isFocused: Bool
  @State private var fieldError: Error?

  var signIn: ClerkKit.SignIn? {
    clerk.auth.currentSignIn
  }

  let factor: Factor

  var body: some View {
    @Bindable var authState = authState

    ScrollView {
      VStack(spacing: 0) {
        VStack(spacing: 8) {
          HeaderView(style: .title, text: "Enter password")
          HeaderView(style: .subtitle, text: "Enter the password for your account")

          if let identifier = factor.safeIdentifier {
            IdentityPreviewView(
              label: identifier.formattedAsPhoneNumberIfPossible,
              isEnabled: !authState.authStartFieldIsLocked(factor.authStartField)
            ) {
              authState.authStartPhoneNumberFieldIsActive = factor.authStartField == .phoneNumber
              navigation.path = []
            }
          }
        }
        .padding(.bottom, 32)

        VStack(spacing: 24) {
          VStack(spacing: 8) {
            ClerkTextField(
              "Enter your password",
              text: $authState.signInPassword,
              isSecure: true,
              fieldState: fieldError != nil ? .error : .default,
              accessibilityIdentifier: ClerkAccessibilityIdentifiers.Auth.SignIn.password
            )
            .textContentType(ClerkE2EEnvironment.isEnabled ? nil : .password)
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
            .focused($isFocused)
            .onFirstAppear {
              isFocused = true
            }

            if let fieldError {
              ErrorText(error: fieldError, alignment: .leading)
                .font(theme.fonts.subheadline)
                .transition(.blurReplace.animation(.default.speed(2)))
                .id(fieldError.localizedDescription)
            }
          }

          AsyncButton {
            await submitPassword()
          } label: { isRunning in
            ContinueButtonLabelView(isActive: isRunning)
          }
          .buttonStyle(.primary())
          .disabled(authState.signInPassword.isEmpty)
          .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Auth.SignIn.continueButton)
          .simultaneousGesture(TapGesture())
        }
        .padding(.bottom, 16)

        HStack(spacing: 16) {
          Button {
            navigation.path.append(
              AuthView.Destination.signInFactorOneUseAnotherMethod(
                currentFactor: factor
              )
            )
          } label: {
            Text("Use another method", bundle: .module)
              .frame(maxWidth: .infinity)
          }
          .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Auth.SignIn.useAnotherMethodButton)

          Rectangle()
            .foregroundStyle(theme.colors.border)
            .frame(width: 1, height: 16)

          Button {
            if signIn?.resetPasswordFactor != nil {
              navigation.path.append(
                AuthView.Destination.signInForgotPassword
              )
            } else {
              navigation.path.append(
                AuthView.Destination.signInFactorOneUseAnotherMethod(
                  currentFactor: factor
                )
              )
            }
          } label: {
            Text("Forgot password?", bundle: .module)
              .frame(maxWidth: .infinity)
          }
        }
        .buttonStyle(
          .primary(
            config: .init(
              emphasis: .none,
              size: .small
            )
          )
        )
        .simultaneousGesture(TapGesture())
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .background(theme.colors.background)
    .sensoryFeedback(.error, trigger: fieldError?.localizedDescription) {
      $1 != nil
    }
  }
}

extension SignInFactorOnePasswordView {
  func submitPassword() async {
    isFocused = false

    do {
      guard jsClerk.client.signIn.id != nil else {
        navigation.path = []
        return
      }

      let jsSignIn = try await jsClerk.client.signIn.attemptFirstFactor(
        .init(strategy: .password, password: authState.signInPassword)
      )
      let signIn = JSCoreAuthMapping.signIn(from: jsSignIn)
      try await JSCoreAuthMapping.activateIfComplete(signIn, using: jsClerk)

      fieldError = nil
      navigation.setToStepForStatus(signIn: signIn)
    } catch {
      fieldError = error
    }
  }
}

#Preview {
  SignInFactorOnePasswordView(factor: .mockPassword)
    .clerkPreview()
}

#Preview("Localized") {
  SignInFactorOnePasswordView(factor: .mockPassword)
    .clerkPreview()
    .environment(\.locale, .init(identifier: "es"))
}

#endif
