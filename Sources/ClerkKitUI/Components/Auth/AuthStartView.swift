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

  var emailIsEnabled: Bool {
    clerk.environment?.enabledFirstFactorAttributes
      .contains("email_address") ?? false
  }

  var usernameIsEnabled: Bool {
    clerk.environment?.enabledFirstFactorAttributes
      .contains("username") ?? false
  }

  var phoneNumberIsEnabled: Bool {
    clerk.environment?.enabledFirstFactorAttributes
      .contains("phone_number") ?? false
  }

  var showIdentifierField: Bool {
    emailIsEnabled || usernameIsEnabled || phoneNumberIsEnabled
  }

  var showIdentifierSwitcher: Bool {
    (emailIsEnabled || usernameIsEnabled) && phoneNumberIsEnabled
  }

  var showOrDivider: Bool {
    !(clerk.environment?.authenticatableSocialProviders ?? []).isEmpty && showIdentifierField
  }

  var shouldStartOnPhoneNumber: Bool {
    guard phoneNumberIsEnabled else { return false }

    if !(emailIsEnabled || usernameIsEnabled) {
      return true
    }

    if !authState.authStartPhoneNumber.isEmpty, authState.authStartIdentifier.isEmpty {
      return true
    }

    return false
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

        headerSection

        VStack(spacing: 24) {
          if showIdentifierField {
            identifierInputSection

            continueButton

            if showIdentifierSwitcher {
              identifierSwitcherButton
            }
          }

          if showOrDivider {
            TextDivider(string: "or")
          }

          socialButtonsSection
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

// MARK: - Subviews

extension AuthStartView {
  private var headerSection: some View {
    VStack(spacing: 8) {
      HeaderView(style: .title, text: titleString)
      HeaderView(style: .subtitle, text: subtitleString)
    }
    .padding(.bottom, 32)
  }

  private var identifierInputSection: some View {
    @Bindable var authState = authState

    return VStack(spacing: 4) {
      if phoneNumberFieldIsActive, phoneNumberIsEnabled {
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
  }

  private var continueButton: some View {
    @Bindable var authState = authState

    return AsyncButton {
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

  private var identifierSwitcherButton: some View {
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

  private var socialButtonsSection: some View {
    SocialButtonLayout {
      ForEach(clerk.environment?.authenticatableSocialProviders ?? []) { provider in
        SocialButton(provider: provider) { result in
          handleTransferFlowResult(result)
        } onError: { error in
          generalError = error
        }
        .simultaneousGesture(TapGesture())
      }
    }
  }
}

// MARK: - Computed Properties

extension AuthStartView {
  private var titleString: LocalizedStringKey {
    switch authState.mode {
    case .signIn, .signInOrUp:
      if let appName = clerk.environment?.displayConfig.applicationName {
        "Continue to \(appName)"
      } else {
        "Continue"
      }
    case .signUp:
      "Create your account"
    }
  }

  private var subtitleString: LocalizedStringKey {
    switch authState.mode {
    case .signIn, .signInOrUp:
      "Welcome! Sign in to continue"
    case .signUp:
      "Welcome! Please fill in the details to get started."
    }
  }

  private var identifierSwitcherString: LocalizedStringKey {
    if phoneNumberFieldIsActive {
      if emailIsEnabled, usernameIsEnabled {
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

  private var emailOrUsernamePlaceholder: LocalizedStringKey {
    switch (emailIsEnabled, usernameIsEnabled) {
    case (true, false):
      "Enter your email"
    case (false, true):
      "Enter your username"
    default:
      "Enter your email or username"
    }
  }
}

// MARK: - Actions

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
      let identifier = phoneNumberFieldIsActive && phoneNumberIsEnabled
        ? authState.authStartPhoneNumber
        : authState.authStartIdentifier

      let signIn = try await clerk.auth.signIn(identifier)

      if signIn.startingFirstFactor?.strategy == .enterpriseSSO {
        let result = try await signIn.authenticateWithEnterpriseSSO()
        handleTransferFlowResult(result)
        return
      }

      authState.setToStepForStatus(signIn: signIn)
    } catch {
      if withSignUp, let clerkApiError = error as? ClerkAPIError, ["form_identifier_not_found", "invitation_account_not_exists"].contains(clerkApiError.code) {
        await signUp()
      } else {
        fieldError = error
      }
    }
  }

  private func signUp() async {
    fieldError = nil

    do {
      let signUp = try await signUpParams()
      authState.setToStepForStatus(signUp: signUp)
    } catch {
      fieldError = error
    }
  }

  private func signUpParams() async throws -> SignUp {
    if phoneNumberFieldIsActive {
      try await clerk.auth.signUp(phoneNumber: authState.authStartPhoneNumber)
    } else if authState.authStartIdentifier.isEmailAddress {
      try await clerk.auth.signUp(emailAddress: authState.authStartIdentifier)
    } else {
      try await clerk.auth.signUp(username: authState.authStartIdentifier)
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
    .clerkPreview()
}

#Preview("Clerk Theme") {
  AuthStartView()
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
}

#Preview("Localized") {
  AuthStartView()
    .clerkPreview()
    .environment(\.clerkTheme, .clerk)
    .environment(\.locale, .init(identifier: "es"))
}

#endif
