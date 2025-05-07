//
//  SignInFactorOnePasswordView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/17/25.
//

#if os(iOS)

import SwiftUI

struct SignInFactorOnePasswordView: View {
  @Environment(\.clerk) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(\.authState) private var authState
  
  @FocusState private var isFocused: Bool
  @State private var fieldError: Error?

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

          if let identifier = factor.safeIdentifier {
            Button {
              authState.path = NavigationPath()
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
              text: $authState.password,
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
          .simultaneousGesture(TapGesture())
        }
        .padding(.bottom, 16)

        HStack(spacing: 16) {
          Button {
            authState.path.append(
              AuthState.Destination.signInFactorOneUseAnotherMethod(
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
            authState.path.append(
              AuthState.Destination.forgotPassword
            )
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
        authState.path = NavigationPath()
        return
      }

      signIn = try await signIn.attemptFirstFactor(
        strategy: .password(password: authState.password)
      )

      fieldError = nil
      authState.setToStepForStatus(signIn: signIn)
    } catch {
      self.fieldError = error
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

#endif
