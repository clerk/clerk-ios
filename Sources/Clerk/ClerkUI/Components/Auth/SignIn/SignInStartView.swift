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

    @State private var error: Error?

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

      if !authState.phoneNumber.isEmpty && authState.identifier.isEmpty {
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
        authState.phoneNumber.isEmpty
      } else {
        authState.identifier.isEmpty
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
              if phoneNumberFieldIsActive && phoneNumberIsEnabled {
                ClerkPhoneNumberField(
                  "Enter your phone number",
                  text: $authState.phoneNumber
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
                  text: $authState.identifier
                )
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .transition(.blurReplace)
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
                SocialButton(provider: provider) { error in
                  self.error = error
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
          strategy: .identifier(phoneNumberFieldIsActive ? authState.phoneNumber : authState.identifier)
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

#endif
