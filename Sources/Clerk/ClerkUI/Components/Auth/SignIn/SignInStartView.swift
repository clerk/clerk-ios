//
//  SignInView.swift
//  Clerk
//
//  Created by Mike Pitre on 4/9/25.
//

#if os(iOS)

  import Factory
  import SwiftUI

  struct SignInStartView: View {
    @Environment(\.clerk) private var clerk
    @Environment(\.clerkTheme) private var theme
    @Environment(\.authState) private var authState
    @Environment(\.dismissKeyboard) private var dismissKeyboard

    @SceneStorage("phoneNumberFieldIsActive") private var phoneNumberFieldIsActive = false

    @State private var fieldError: Error?
    @State private var generalError: Error?

    var signInString: LocalizedStringKey {
      if let appName = clerk.environment.displayConfig?.applicationName {
        return "Continue to \(appName)"
      } else {
        return "Continue"
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

      if !authState.signInPhoneNumber.isEmpty && authState.signInIdentifier.isEmpty {
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
        authState.signInPhoneNumber.isEmpty
      } else {
        authState.signInIdentifier.isEmpty
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
            HeaderView(style: .title, text: signInString)
            HeaderView(style: .subtitle, text: "Welcome! Sign in to continue")
          }
          .padding(.bottom, 32)

          VStack(spacing: 24) {
            if showIdentifierField {
              VStack(spacing: 4) {
                if phoneNumberFieldIsActive && phoneNumberIsEnabled {
                  ClerkPhoneNumberField(
                    "Enter your phone number",
                    text: $authState.signInPhoneNumber,
                    fieldState: fieldError != nil ? .error : .default
                  )
                  .transition(.blurReplace)
                  .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                      Spacer()
                      Button("Done") {
                        dismissKeyboard()
                      }
                      .tint(theme.colors.text)
                    }
                  }
                } else {
                  ClerkTextField(
                    emailOrUsernamePlaceholder,
                    text: $authState.signInIdentifier,
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
            }

            AsyncButton {
              await createSignIn()
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
            .disabled(continueIsDisabled)
            .simultaneousGesture(TapGesture())

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
      .background(theme.colors.background)
      .clerkErrorPresenting($generalError)
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

  extension SignInStartView {

    func createSignIn() async {
      dismissKeyboard()

      do {
        let signIn = try await SignIn.create(
          strategy: .identifier(
            phoneNumberFieldIsActive
              ? authState.signInPhoneNumber
              : authState.signInIdentifier
          )
        )

        fieldError = nil
        authState.setToStepForStatus(signIn: signIn)
      } catch {
        if authState.mode == .signInOrUp,
          let clerkApiError = error as? ClerkAPIError,
          ["form_identifier_not_found", "invitation_account_not_exists"].contains(clerkApiError.code)
        {
          await transferToSignUp()
        } else {
          self.fieldError = error
        }
      }
    }

    private func transferToSignUp() async {
      do {
        let signUp = try await SignUp.create(strategy: transferableSignUpParams)
        authState.setToStepForStatus(signUp: signUp)
      } catch {
        self.fieldError = error
      }
    }
    
    private var transferableSignUpParams: SignUp.CreateStrategy {
      if phoneNumberFieldIsActive {
        return .standard(phoneNumber: authState.signInPhoneNumber)
      } else {
        if authState.signInIdentifier.isEmailAddress {
          return .standard(emailAddress: authState.signInIdentifier)
        } else {
          return .standard(username: authState.signInIdentifier)
        }
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
      .environment(\.clerkTheme, .clerk)
      .environment(\.locale, .init(identifier: "en"))
  }

#endif
