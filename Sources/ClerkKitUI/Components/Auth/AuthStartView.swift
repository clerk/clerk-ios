//
//  AuthStartView.swift
//  Clerk
//

// swiftlint:disable file_length

#if os(iOS) || os(macOS)

import ClerkKit
import SwiftUI

struct AuthStartView: View {
  // MARK: - Environment

  @Environment(Clerk.self) private var clerk
  @Environment(\.clerkTheme) private var theme
  @Environment(AuthNavigation.self) private var navigation
  @Environment(AuthState.self) private var authState
  @Environment(\.dismissKeyboard) private var dismissKeyboard

  // MARK: - State

  @State private var fieldError: Error?
  @State private var generalError: Error?
  @State private var automaticPasskeySignInTask: Task<Void, Never>?

  // MARK: - Configuration

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

  var phoneNumberFieldIsActive: Bool {
    authState.authStartPhoneNumberFieldIsActive
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

  var phoneNumberInputIsActive: Bool {
    phoneNumberIsEnabled && (phoneNumberFieldIsActive || !(emailIsEnabled || usernameIsEnabled))
  }

  var activeIdentifier: String {
    phoneNumberInputIsActive ? authState.authStartPhoneNumber : authState.authStartIdentifier
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

  var passkeySignInIsAvailable: Bool {
    switch authState.mode {
    case .signIn, .signInOrUp:
      clerk.environment?.enabledFirstFactorAttributes.contains("passkey") == true &&
        !lockedInitialIdentifierIsActive
    case .signUp:
      false
    }
  }

  var lockedInitialIdentifierIsActive: Bool {
    authState.prefilledFieldsAreLocked && authState.hasInitialIdentifier
  }

  var passkeyAutomaticModalIsEnabled: Bool {
    #if os(iOS) && !targetEnvironment(macCatalyst)
    guard let environment = clerk.environment else { return false }
    // Clerk's AutoFill setting controls the no-interaction modal, not iOS's text-field AutoFill request.
    return passkeySignInIsAvailable &&
      environment.userSettings.passkeySettings?.allowAutofill == true
    #else
    false
    #endif
  }

  var passkeySignInIsEnabled: Bool {
    #if os(iOS) && !targetEnvironment(macCatalyst)
    passkeySignInIsAvailable
    #else
    false
    #endif
  }

  var passkeySignInTaskIsEnabled: Bool {
    #if os(iOS) && !targetEnvironment(macCatalyst)
    passkeySignInIsEnabled && navigation.path.isEmpty
    #else
    false
    #endif
  }

  private var socialProvidersMinusLastUsed: [OAuthProvider] {
    let providers = clerk.environment?.authenticatableSocialProviders ?? []
    guard let lastUsedSocialProvider = lastUsedAuth?.socialProvider else { return providers }
    return providers.filter { $0 != lastUsedSocialProvider }
  }

  private var lastUsedAuth: LastUsedAuth? {
    guard authState.persistsIdentifiers else { return nil }
    return LastUsedAuth(environment: clerk.environment)
  }

  // MARK: - Display Strings

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

  // MARK: - Body

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
    #if os(iOS)
    .scrollDismissesKeyboard(.interactively)
    #endif
    .clerkErrorPresenting($generalError)
    .background(theme.colors.background)
    .sensoryFeedback(.error, trigger: fieldError?.localizedDescription) {
      $1 != nil
    }
    .onFirstAppear {
      if authState.hasInitialIdentifier {
        authState.authStartPhoneNumberFieldIsActive = shouldStartOnPhoneNumber
      } else if shouldStartOnPhoneNumber {
        authState.authStartPhoneNumberFieldIsActive = true
      }
    }
    #if os(iOS) && !targetEnvironment(macCatalyst)
    .task(id: passkeySignInTaskIsEnabled) {
      guard passkeySignInTaskIsEnabled else { return }
      let includeAutomaticModal = !authState.automaticPasskeySignInHasStarted
      authState.automaticPasskeySignInHasStarted = true
      let task = Task { await startPasskeySignIn(includeAutomaticModal: includeAutomaticModal) }
      automaticPasskeySignInTask = task
      await withTaskCancellationHandler {
        await task.value
      } onCancel: {
        task.cancel()
      }
      automaticPasskeySignInTask = nil
    }
    #endif
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
    VStack(spacing: 4) {
      identifierField
      fieldErrorView
    }
  }

  @ViewBuilder
  private var identifierField: some View {
    @Bindable var authState = authState

    if phoneNumberInputIsActive {
      ClerkPhoneNumberField(
        "Enter your phone number",
        text: $authState.authStartPhoneNumber,
        fieldState: fieldError != nil ? .error : .default,
        isEnabled: !authState.authStartPhoneNumberIsLocked,
        accessibilityIdentifier: ClerkAccessibilityIdentifiers.Auth.Start.phoneNumber
      )
      .transition(.blurReplace)
      .lastUsedAuthBadgeOverlay(lastUsedAuth?.showsPhoneBadge ?? false)
    } else {
      VStack {
        ClerkTextField(
          emailOrUsernamePlaceholder,
          text: $authState.authStartIdentifier,
          fieldState: fieldError != nil ? .error : .default,
          isEnabled: !authState.authStartIdentifierIsLocked,
          accessibilityIdentifier: ClerkAccessibilityIdentifiers.Auth.Start.identifier
        )
        .textContentType(.username)
        #if os(iOS)
        .keyboardType(.emailAddress)
        .textInputAutocapitalization(.never)
        #endif
        .lastUsedAuthBadgeOverlay(lastUsedAuth?.showsEmailUsernameBadge ?? false)
      }
      .transition(.blurReplace)
    }
  }

  @ViewBuilder
  private var fieldErrorView: some View {
    if let fieldError {
      ErrorText(error: fieldError, alignment: .leading)
        .font(theme.fonts.subheadline)
        .transition(.blurReplace.animation(.default.speed(2)))
        .id(fieldError.localizedDescription)
    }
  }

  private var continueButton: some View {
    @Bindable var authState = authState

    return AsyncButton {
      await startAuth()
    } label: { isRunning in
      ContinueButtonLabelView(isActive: isRunning)
    }
    .buttonStyle(.primary())
    .disabled(activeIdentifier.isEmpty)
    .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Auth.Start.continueButton)
    .simultaneousGesture(TapGesture())
  }

  private var identifierSwitcherButton: some View {
    Button {
      withAnimation(.default.speed(2)) {
        authState.authStartPhoneNumberFieldIsActive.toggle()
      }
    } label: {
      Text(identifierSwitcherString, bundle: .module)
        .id(phoneNumberFieldIsActive)
    }
    .buttonStyle(.primary(config: .init(emphasis: .none, size: .small)))
    .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Auth.Start.identifierSwitcherButton)
    .simultaneousGesture(TapGesture())
  }

  private var socialButtonsSection: some View {
    VStack(spacing: 8) {
      if let lastUsedProvider = lastUsedAuth?.socialProvider {
        SocialButton(
          provider: lastUsedProvider,
          transferable: authState.transferable,
          unsafeMetadata: authState.unsafeMetadata,
          onStart: cancelAutomaticPasskeySignIn,
          onSuccess: handleTransferFlowResult,
          onError: { generalError = $0 }
        )
        .lastUsedAuthBadgeOverlay(true)
        .simultaneousGesture(TapGesture())
      }

      if !socialProvidersMinusLastUsed.isEmpty {
        SocialButtonLayout {
          ForEach(socialProvidersMinusLastUsed) { provider in
            SocialButton(
              provider: provider,
              transferable: authState.transferable,
              unsafeMetadata: authState.unsafeMetadata,
              showsTitle: socialProvidersMinusLastUsed.count == 1,
              onStart: cancelAutomaticPasskeySignIn,
              onSuccess: handleTransferFlowResult,
              onError: { generalError = $0 }
            )
            .simultaneousGesture(TapGesture())
          }
        }
      }
    }
  }
}

// MARK: - Actions

extension AuthStartView {
  private enum PasskeySignInResult {
    case completed
    case continueWithAutofill
    case stopped
  }

  func startAuth() async {
    cancelAutomaticPasskeySignIn()
    dismissKeyboard()

    switch authState.mode {
    case .signInOrUp: await signIn(withSignUp: true)
    case .signIn: await signIn(withSignUp: false)
    case .signUp: await signUp()
    }
  }

  private func cancelAutomaticPasskeySignIn() {
    automaticPasskeySignInTask?.cancel()
    automaticPasskeySignInTask = nil
  }

  private func signIn(withSignUp: Bool) async {
    fieldError = nil

    do {
      // Store the identifier type for "last used" badge disambiguation
      storeIdentifierType()

      let signIn = try await clerk.auth.signIn(activeIdentifier)

      if signIn.startingFirstFactor?.strategy == .enterpriseSSO {
        let result = try await signIn.authenticateWithEnterpriseSSO(
          transferable: authState.transferable,
          unsafeMetadata: authState.unsafeMetadata
        )
        handleTransferFlowResult(result)
        return
      }

      navigation.setToStepForStatus(signIn: signIn)
    } catch {
      if withSignUp, let clerkApiError = error as? ClerkAPIError, ["form_identifier_not_found", "invitation_account_not_exists"].contains(clerkApiError.code) {
        await signUp()
      } else {
        fieldError = error
      }
    }
  }

  private func signInWithPasskey(
    autofill: Bool,
    preferImmediatelyAvailableCredentials: Bool
  ) async -> PasskeySignInResult {
    do {
      let signIn = try await clerk.auth.signInWithPasskey(
        autofill: autofill,
        preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
      )

      guard !Task.isCancelled else { return .stopped }
      generalError = nil
      guard navigation.path.isEmpty else { return .stopped }
      navigation.setToStepForStatus(signIn: signIn)
      return .completed
    } catch {
      if Task.isCancelled || error.isCancellationError { return .stopped }
      if error.isUserCancelledError { return .continueWithAutofill }
      guard navigation.path.isEmpty else { return .stopped }

      generalError = error
      if autofill {
        ClerkLogger.error("Failed to authenticate with passkey autofill", error: error)
      } else {
        ClerkLogger.error("Failed to authenticate with passkey", error: error)
      }
      // Keep iOS text-field AutoFill armed after a modal error so users can
      // pick another passkey without a second modal.
      return autofill ? .stopped : .continueWithAutofill
    }
  }

  #if os(iOS) && !targetEnvironment(macCatalyst)
  private func startPasskeySignIn(includeAutomaticModal: Bool) async {
    guard navigation.path.isEmpty else { return }

    if includeAutomaticModal, passkeyAutomaticModalIsEnabled {
      let result = await signInWithPasskey(
        autofill: false,
        preferImmediatelyAvailableCredentials: true
      )
      guard case .continueWithAutofill = result else { return }
    }

    guard navigation.path.isEmpty else { return }
    // Clerk's AutoFill setting gates the automatic modal above; this keeps
    // iOS text-field AutoFill available.
    await signInWithPasskey(
      autofill: true,
      preferImmediatelyAvailableCredentials: true
    )
  }
  #endif

  private func signUp() async {
    fieldError = nil

    do {
      let signUp = try await signUpParams()
      navigation.setToStepForStatus(signUp: signUp)
    } catch {
      fieldError = error
    }
  }

  private func signUpParams() async throws -> SignUp {
    if phoneNumberInputIsActive {
      try await clerk.auth.signUp(
        phoneNumber: authState.authStartPhoneNumber,
        unsafeMetadata: authState.unsafeMetadata
      )
    } else if authState.authStartIdentifier.isEmailAddress {
      try await clerk.auth.signUp(
        emailAddress: authState.authStartIdentifier,
        unsafeMetadata: authState.unsafeMetadata
      )
    } else {
      try await clerk.auth.signUp(
        username: authState.authStartIdentifier,
        unsafeMetadata: authState.unsafeMetadata
      )
    }
  }

  private func handleTransferFlowResult(_ result: TransferFlowResult) {
    switch result {
    case .signIn(let signIn):
      navigation.setToStepForStatus(signIn: signIn)
    case .signUp(let signUp):
      navigation.setToStepForStatus(signUp: signUp)
    }
  }

  private func storeIdentifierType() {
    if phoneNumberInputIsActive {
      authState.storeLastUsedIdentifierType(.phone)
    } else if authState.authStartIdentifier.isEmailAddress {
      authState.storeLastUsedIdentifierType(.email)
    } else {
      authState.storeLastUsedIdentifierType(.username)
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
