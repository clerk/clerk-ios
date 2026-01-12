//
//  SignInFactorOnePasswordView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/17/25.
//

#if os(iOS)

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
            Button {
              navigation.path = []
            } label: {
              IdentityPreviewView(label: identifier.formattedAsPhoneNumberIfPossible)
            }
            .buttonStyle(.secondary(config: .init(size: .small)))
            .simultaneousGesture(TapGesture())
          }
        }
        .padding(.bottom, 32)

        VStack(spacing: 24) {
          VStack(spacing: 8) {
            ClerkTextField(
              "Enter your password",
              text: $authState.signInPassword,
              isSecure: true,
              fieldState: fieldError != nil ? .error : .default
            )
            .textContentType(.password)
            .textInputAutocapitalization(.never)
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
            HStack(spacing: 4) {
              Text("Continue", bundle: .module)
              Image("icon-triangle-right", bundle: .module)
                .foregroundStyle(theme.colors.primaryForeground)
                .opacity(0.6)
            }
            .frame(maxWidth: .infinity)
            .overlayProgressView(isActive: isRunning) {
              SpinnerView(color: theme.colors.primaryForeground)
            }
          }
          .buttonStyle(.primary())
          .disabled(authState.signInPassword.isEmpty)
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
      guard var signIn else {
        navigation.path = []
        return
      }

      signIn = try await signIn.authenticateWithPassword(authState.signInPassword)

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
