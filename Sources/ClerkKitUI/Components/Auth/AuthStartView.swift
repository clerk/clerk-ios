//
//  AuthStartView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/9/25.
//

#if os(iOS)

import ClerkKit
import SwiftUI

struct AuthStartView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthState.self) private var authState
  @Environment(\.dismissKeyboard) private var dismissKeyboard

  @SceneStorage("phoneNumberFieldIsActive") private var phoneNumberFieldIsActive = false

  @State private var fieldError: Error?
  @State private var generalError: Error?

  var titleString: LocalizedStringKey {
    switch authState.mode {
    case .signIn, .signInOrUp:
      if let appName = clerk.environment.displayConfig?.applicationName {
        return "Continue to \(appName)"
      } else {
        return "Continue"
      }
    case .signUp:
      return "Create your account"
    }
  }

  var subtitleString: LocalizedStringKey {
    switch authState.mode {
    case .signIn, .signInOrUp:
      "Welcome! Sign in to continue"
    case .signUp:
      "Welcome! Please fill in the details to get started."
    }
  }

  var emailIsEnabled: Bool {
    clerk.environment.enabledFirstFactorAttributes
      .contains("email_address")
  }

  var usernameIsEnabled: Bool {
    clerk.environment.enabledFirstFactorAttributes
      .contains("username")
  }

  var phoneNumberIsEnabled: Bool {
    clerk.environment.enabledFirstFactorAttributes
      .contains("phone_number")
  }

  var showIdentifierField: Bool {
    emailIsEnabled || usernameIsEnabled || phoneNumberIsEnabled
  }

  var showIdentifierSwitcher: Bool {
    (emailIsEnabled || usernameIsEnabled) && phoneNumberIsEnabled
  }

  var identifierSwitcherString: LocalizedStringKey {
    if phoneNumberFieldIsActive {
      if emailIsEnabled && usernameIsEnabled {
        "Use email address or username"
      } else if emailIsEnabled {
        "Use email address"
      } else if usernameIsEnabled {
        "Use username"
      } else {
        ""
      }
    } else {
      "Use phone number"
    }
  }

  var shouldStartOnPhoneNumber: Bool {
    guard phoneNumberIsEnabled else { return false }

    if !(emailIsEnabled || usernameIsEnabled) {
      return true
    }

    if !authState.authStartPhoneNumber.isEmpty && authState.authStartIdentifier.isEmpty {
      return true
    }

    return false
  }

  var emailOrUsernamePlaceholder: LocalizedStringKey {
    switch (emailIsEnabled, usernameIsEnabled) {
    case (true, false):
      "Enter your email"
    case (false, true):
      "Enter your username"
    default:
      "Enter your email or username"
    }
  }

  var showOrDivider: Bool {
    !clerk.environment.authenticatableSocialProviders.isEmpty && showIdentifierField
  }

  var continueIsDisabled: Bool {
    if phoneNumberFieldIsActive {
      authState.authStartPhoneNumber.isEmpty
    } else {
      authState.authStartIdentifier.isEmpty
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
          HeaderView(style: .title, text: titleString)
          HeaderView(style: .subtitle, text: subtitleString)
        }
        .padding(.bottom, 32)

        VStack(spacing: 24) {
          if showIdentifierField {
            VStack(spacing: 4) {
              if phoneNumberFieldIsActive && phoneNumberIsEnabled {
                ClerkPhoneNumberField(
                  "Enter your phone number",
                  text: $authState.authStartPhoneNumber,
                  fieldState: fieldError != nil ? .error : .default
                )
                .transition(.blurReplace)
              } else {
                ClerkTextField(
                  emailOrUsernamePlaceholder,
                  text: $authState.authStartIdentifier,
                  fieldState: fieldError != nil ? .error : .default
                )
                .textContentType(.username)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .transition(.blurReplace)
              }

              if let fieldError {
                ErrorText(error: fieldError, alignment: .leading)
                  .font(theme.fonts.subheadline)
                  .transition(.blurReplace.animation(.default.speed(2)))
                  .id(fieldError.localizedDescription)
              }

              AsyncButton {
                await startAuth()
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
              .disabled(continueIsDisabled)
              .simultaneousGesture(TapGesture())
            }
          }

          if showIdentifierSwitcher {
            Button {
              withAnimation(.default.speed(2)) {
                phoneNumberFieldIsActive.toggle()
              }
            } label: {
              Text(identifierSwitcherString, bundle: .module)
                .id(phoneNumberFieldIsActive)
            }
            .buttonStyle(.primary(config: .init(emphasis: .none, size: .small)))
            .simultaneousGesture(TapGesture())
          }

          if showOrDivider {
            TextDivider(string: "or")
          }

          SocialButtonLayout {
            ForEach(clerk.environment.authenticatableSocialProviders) { provider in
              SocialButton(provider: provider) { result in
                switch result {
                case .signIn(let signIn):
                  authState.setToStepForStatus(signIn: signIn)
                case .signUp(let signUp):
                  authState.setToStepForStatus(signUp: signUp)
                }
                .padding(.bottom, 32)

                VStack(spacing: 24) {
                    if showIdentifierField {
                        VStack(spacing: 4) {
                            if phoneNumberFieldIsActive && phoneNumberIsEnabled {
                                ClerkPhoneNumberField(
                                    "Enter your phone number",
                                    text: $authState.authStartPhoneNumber,
                                    fieldState: fieldError != nil ? .error : .default
                                )
                                .transition(.blurReplace)
                            } else {
                                ClerkTextField(
                                    emailOrUsernamePlaceholder,
                                    text: $authState.authStartIdentifier,
                                    fieldState: fieldError != nil ? .error : .default
                                )
                                .textContentType(.username)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .transition(.blurReplace)
                            }

                            if let fieldError {
                                ErrorText(error: fieldError, alignment: .leading)
                                    .font(theme.fonts.subheadline)
                                    .transition(.blurReplace.animation(.default.speed(2)))
                                    .id(fieldError.localizedDescription)
                            }
                        }

                        AsyncButton {
                            await startAuth()
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
                        .disabled(continueIsDisabled)
                        .simultaneousGesture(TapGesture())
                    }

                    if showIdentifierSwitcher {
                        Button {
                            withAnimation(.default.speed(2)) {
                                phoneNumberFieldIsActive.toggle()
                            }
                        } label: {
                            Text(identifierSwitcherString, bundle: .module)
                                .id(phoneNumberFieldIsActive)
                        }
                        .buttonStyle(.primary(config: .init(emphasis: .none, size: .small)))
                        .simultaneousGesture(TapGesture())
                    }

                    if showOrDivider {
                        TextDivider(string: "or")
                    }

                    SocialButtonLayout {
                        ForEach(clerk.environment.authenticatableSocialProviders) { provider in
                            SocialButton(provider: provider) { result in
                              handleTransferFlowResult(result)
                            } onError: { error in
                              self.generalError = error
                            }
                            .simultaneousGesture(TapGesture())
                        }
                    }
                }
                .padding(.bottom, 32)

                SecuredByClerkView()
            }
            .padding(16)
        }
        .scrollDismissesKeyboard(.interactively)
        .clerkErrorPresenting($generalError)
        .background(theme.colors.background)
        .sensoryFeedback(.error, trigger: fieldError?.localizedDescription) {
            $1 != nil
        }
        .taskOnce {
            if shouldStartOnPhoneNumber {
                phoneNumberFieldIsActive = true
            }
          }
        }
        .padding(.bottom, 32)

        SecuredByClerkView()
      }
      .padding(16)
    }
    .scrollDismissesKeyboard(.interactively)
    .clerkErrorPresenting($generalError)
    .background(theme.colors.background)
    .sensoryFeedback(.error, trigger: fieldError?.localizedDescription) {
      $1 != nil
    }
    .taskOnce {
      if shouldStartOnPhoneNumber {
        phoneNumberFieldIsActive = true
      }
    }
  }
}

extension AuthStartView {

  func startAuth() async {
    dismissKeyboard()

    switch authState.mode {
    case .signInOrUp: await signIn(withSignUp: true)
    case .signIn: await signIn(withSignUp: false)
    case .signUp: await signUp()
    }
  }

  private func signIn(withSignUp: Bool) async {
    fieldError = nil

    do {
      var signIn = try await SignIn.create(
        strategy: .identifier(
          phoneNumberFieldIsActive && phoneNumberIsEnabled
            ? authState.authStartPhoneNumber
            : authState.authStartIdentifier
        )
      )

      if signIn.startingFirstFactor?.strategy == "enterprise_sso" {
        signIn = try await signIn.prepareFirstFactor(strategy: .enterpriseSSO())

        if signIn.firstFactorVerification?.externalVerificationRedirectUrl != nil {
          let result = try await signIn.authenticateWithRedirect()
          handleTransferFlowResult(result)
          return
        }
      }

      authState.setToStepForStatus(signIn: signIn)
    } catch {
      if withSignUp, let clerkApiError = error as? ClerkAPIError, ["form_identifier_not_found", "invitation_account_not_exists"].contains(clerkApiError.code) {
        await signUp()
      } else {
        self.fieldError = error
      }
    }
  }

  private func signUp() async {
    fieldError = nil

    private func handleTransferFlowResult(_ result: TransferFlowResult) {
      switch result {
      case .signIn(let signIn):
        if let error = signIn.firstFactorVerification?.error {
          generalError = error
        } else {
          authState.setToStepForStatus(signIn: signIn)
        }
      case .signUp(let signUp):
        if let verification = signUp.verifications.first(where: { $0.key == "external_account" })?.value,
           let error = verification.error {
          generalError = error
        } else {
          authState.setToStepForStatus(signUp: signUp)
        }
      }
    }
  }

  private var signUpParams: SignUp.CreateStrategy {
    if phoneNumberFieldIsActive {
      return .standard(phoneNumber: authState.authStartPhoneNumber)
    } else {
      if authState.authStartIdentifier.isEmailAddress {
        return .standard(emailAddress: authState.authStartIdentifier)
      } else {
        return .standard(username: authState.authStartIdentifier)
      }
    }
  }

  private func handleTransferFlowResult(_ result: TransferFlowResult) {
    switch result {
    case .signIn(let signIn):
      authState.setToStepForStatus(signIn: signIn)
    case .signUp(let signUp):
      authState.setToStepForStatus(signUp: signUp)
    }
  }

}

#Preview {
  AuthStartView()
    .clerkPreviewMocks()
}

#Preview("Clerk Theme") {
  AuthStartView()
    .clerkPreviewMocks()
    .environment(\.clerkTheme, .clerk)
}

#Preview("Localized") {
  AuthStartView()
    .clerkPreviewMocks()
    .environment(\.clerkTheme, .clerk)
    .environment(\.locale, .init(identifier: "en"))
}

#endif
