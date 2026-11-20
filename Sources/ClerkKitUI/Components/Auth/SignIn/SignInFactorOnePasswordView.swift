//
//  SignInFactorOnePasswordView.swift
//  Clerk
//

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct SignInFactorOnePasswordView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation
  @Environment(AuthState.self) private var authState

  @FocusState private var isFocused: Bool
  @State private var fieldError: Error?

  var signIn: SignIn? {
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

        SignInPasswordActionsView(
          onUseAnotherMethod: useAnotherMethodAction,
          onForgotPassword: forgotPasswordAction
        )
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
  var showsOtherMethods: Bool {
    SignInFactorMode.firstFactor.showsUseAnotherMethod(
      signIn: signIn,
      currentFactor: factor,
      socialProviders: clerk.environment?.authenticatableSocialProviders ?? []
    )
  }

  var useAnotherMethodAction: (() -> Void)? {
    guard showsOtherMethods else { return nil }
    return { showOtherMethods() }
  }

  var forgotPasswordAction: (() -> Void)? {
    guard signIn?.resetPasswordFactor != nil || showsOtherMethods else { return nil }
    return { showPasswordReset() }
  }

  func showOtherMethods() {
    navigation.path.append(
      AuthView.Destination.signInFactorOneUseAnotherMethod(currentFactor: factor)
    )
  }

  func showPasswordReset() {
    if signIn?.resetPasswordFactor != nil {
      navigation.path.append(AuthView.Destination.signInForgotPassword)
    } else {
      showOtherMethods()
    }
  }

  func submitPassword() async {
    isFocused = false

    guard let attempt = signIn else {
      navigation.path = []
      return
    }
    let submittedPath = navigation.path

    do {
      let signIn = try await attempt.authenticateWithPassword(authState.signInPassword)

      fieldError = nil
      navigation.setToStepForStatus(signIn: signIn)
    } catch {
      guard Self.isCurrentSubmission(
        attemptID: attempt.id, submittedPath: submittedPath, signIn: signIn, navigation: navigation
      ) else { return }
      if let destination = Self.destination(afterPasswordError: error, signIn: signIn) {
        fieldError = nil
        navigation.path.append(destination)
      } else {
        fieldError = error
      }
    }
  }

  static func isCurrentSubmission(
    attemptID: String, submittedPath: [AuthView.Destination], signIn: SignIn?, navigation: AuthNavigation
  ) -> Bool {
    signIn?.id == attemptID && navigation.path == submittedPath
  }

  static func destination(afterPasswordError error: Error, signIn: SignIn?) -> AuthView.Destination? {
    guard (error as? ClerkAPIError)?.code == "password_reset_required",
          signIn?.resetPasswordFactor != nil
    else { return nil }
    return .signInPasswordResetRequired
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
