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
  @State private var automaticPasskeySignInTaskGeneration = 0
  @State private var automaticPasskeySignInRestartID = 0
  @State private var automaticPasskeySignInHasStarted = false
  #if os(iOS)
  @State private var trustedDeviceAvailability: TrustedDeviceAvailability?
  #endif

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
    hasSocialProviders && showIdentifierField
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
    passkeySignInIsAvailable(environment: clerk.environment)
  }

  func passkeySignInIsAvailable(environment: Clerk.Environment?) -> Bool {
    switch authState.mode {
    case .signIn, .signInOrUp:
      environment?.passkeyIsEnabled == true &&
        !lockedInitialIdentifierIsActive
    case .signUp:
      false
    }
  }

  var lockedInitialIdentifierIsActive: Bool {
    authState.prefilledFieldsAreLocked && authState.hasInitialIdentifier
  }

  func passkeyAutomaticModalIsEnabled(environment: Clerk.Environment) -> Bool {
    #if os(iOS) && !targetEnvironment(macCatalyst)
    // Clerk's AutoFill setting controls the no-interaction modal, not iOS's text-field AutoFill request.
    return passkeySignInIsAvailable(environment: environment) &&
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

  var passkeyAutoFillFallbackIsEnabled: Bool {
    passkeyAutoFillFallbackIsEnabled(environment: clerk.environment)
  }

  func passkeyAutoFillFallbackIsEnabled(environment: Clerk.Environment?) -> Bool {
    #if os(iOS) && !targetEnvironment(macCatalyst)
    let enabledAttributes = environment?.enabledFirstFactorAttributes ?? []
    return passkeySignInIsAvailable(environment: environment) &&
      !phoneNumberInputIsActive &&
      (enabledAttributes.contains("email_address") || enabledAttributes.contains("username"))
    #else
    false
    #endif
  }

  private var passkeySignInTaskID: Int? {
    passkeySignInTaskIsEnabled ? automaticPasskeySignInRestartID : nil
  }

  private var socialProvidersMinusLastUsed: [OAuthProvider] {
    guard let lastUsedSocialProvider = lastUsedAuth?.socialProvider else { return socialProviders }
    return socialProviders.filter { $0 != lastUsedSocialProvider }
  }

  private var socialProviders: [OAuthProvider] {
    clerk.environment?.authenticatableSocialProviders ?? []
  }

  private var lastUsedAuth: LastUsedAuth? {
    guard authState.persistsIdentifiers else { return nil }
    return LastUsedAuth(environment: clerk.environment)
  }

  private var hasSocialProviders: Bool {
    !(clerk.environment?.authenticatableSocialProviders ?? []).isEmpty
  }

  #if os(iOS)
  private var trustedDeviceFeatureIsEnabled: Bool {
    clerk.environment?.authConfig.nativeSettings.trustedDeviceSignInEnabled == true
  }

  private var shouldShowTrustedDeviceSignIn: Bool {
    authState.mode != .signUp && trustedDeviceAvailability?.isAvailable == true
  }

  private var trustedDeviceIdentifierHint: String? {
    let trimmedIdentifier = activeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmedIdentifier.isEmpty ? nil : trimmedIdentifier
  }

  private var trustedDeviceAvailabilityRefreshState: TrustedDeviceAvailabilityRefreshState {
    guard trustedDeviceFeatureIsEnabled else {
      return .disabled
    }
    guard clerk.session?.status == .active, let sessionID = clerk.session?.id else {
      return .signedOut(identifierHint: trustedDeviceIdentifierHint)
    }
    return .signedIn(activeSessionID: sessionID, identifierHint: trustedDeviceIdentifierHint)
  }
  #endif

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

        headerSection

        VStack(spacing: 24) {
          #if os(iOS)
          if shouldShowTrustedDeviceSignIn {
            trustedDeviceSignInButton

            if showIdentifierField || hasSocialProviders {
              TextDivider(string: "or")
            }
          }
          #endif

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
    .task(id: passkeySignInTaskID) {
      guard passkeySignInTaskID != nil else { return }
      let includeAutomaticModal = !automaticPasskeySignInHasStarted
      automaticPasskeySignInTaskGeneration += 1
      let taskGeneration = automaticPasskeySignInTaskGeneration
      let task = Task { await startPasskeySignIn(includeAutomaticModal: includeAutomaticModal) }
      automaticPasskeySignInTask = task
      await withTaskCancellationHandler {
        await task.value
      } onCancel: {
        task.cancel()
      }
      if automaticPasskeySignInTaskGeneration == taskGeneration {
        automaticPasskeySignInTask = nil
      }
    }
    .onChange(of: clerk.environmentRefreshCheckpoint) { _, _ in
      restartAutomaticPasskeySignInAfterEnvironmentRefreshIfNeeded()
    }
    #endif
    #if os(iOS)
    .task(id: trustedDeviceAvailabilityRefreshState) {
      await refreshTrustedDeviceAvailability()
    }
    #endif
  }
}

#if os(iOS)
private enum TrustedDeviceAvailabilityRefreshState: Equatable {
  case disabled
  case signedOut(identifierHint: String?)
  case signedIn(activeSessionID: String, identifierHint: String?)
}
#endif

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
      cancelAutomaticPasskeySignIn()
      withAnimation(.default.speed(2)) {
        authState.authStartPhoneNumberFieldIsActive.toggle()
      }
      restartAutomaticPasskeySignInIfNeeded()
    } label: {
      Text(identifierSwitcherString, bundle: .module)
        .id(phoneNumberFieldIsActive)
    }
    .buttonStyle(.primary(config: .init(emphasis: .none, size: .small)))
    .accessibilityIdentifier(ClerkAccessibilityIdentifiers.Auth.Start.identifierSwitcherButton)
    .simultaneousGesture(TapGesture())
  }

  #if os(iOS)
  private var trustedDeviceSignInButton: some View {
    TrustedDeviceSignInButton {
      await signInWithTrustedDevice()
    }
    .simultaneousGesture(TapGesture())
  }
  #endif

  private var socialButtonsSection: some View {
    VStack(spacing: 8) {
      if lastUsedAuth?.socialProvider != nil || !socialProvidersMinusLastUsed.isEmpty {
        SocialButtonGroup(
          providers: socialProviders,
          lastUsedProvider: lastUsedAuth?.socialProvider
        ) { provider, showsTitle, isLastUsed in
          SocialButton(
            provider: provider,
            transferable: authState.transferable,
            unsafeMetadata: authState.unsafeMetadata,
            showsTitle: showsTitle,
            onStart: cancelAutomaticPasskeySignIn,
            onSuccess: handleTransferFlowResult,
            onError: { error in
              generalError = error
              restartAutomaticPasskeySignInIfNeeded()
            },
            onCancel: restartAutomaticPasskeySignInIfNeeded
          )
          .lastUsedAuthBadgeOverlay(isLastUsed)
          .simultaneousGesture(TapGesture())
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

    let shouldRestartPasskeySignIn = switch authState.mode {
    case .signInOrUp: await signIn(withSignUp: true)
    case .signIn: await signIn(withSignUp: false)
    case .signUp: await signUp()
    }

    if shouldRestartPasskeySignIn {
      restartAutomaticPasskeySignInIfNeeded()
    }
  }

  private func cancelAutomaticPasskeySignIn() {
    automaticPasskeySignInTaskGeneration += 1
    automaticPasskeySignInTask?.cancel()
    automaticPasskeySignInTask = nil
  }

  private func restartAutomaticPasskeySignInIfNeeded() {
    guard passkeySignInTaskIsEnabled else { return }
    automaticPasskeySignInRestartID += 1
  }

  private func restartAutomaticPasskeySignInAfterEnvironmentRefreshIfNeeded() {
    guard !automaticPasskeySignInHasStarted, automaticPasskeySignInTask == nil else { return }
    restartAutomaticPasskeySignInIfNeeded()
  }

  private func signIn(withSignUp: Bool) async -> Bool {
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
        return false
      }

      navigation.setToStepForStatus(signIn: signIn)
      return signInStatusStaysOnStart(signIn.status)
    } catch {
      if withSignUp, let clerkApiError = error as? ClerkAPIError, ["form_identifier_not_found", "invitation_account_not_exists"].contains(clerkApiError.code) {
        return await signUp()
      } else {
        fieldError = error
        return true
      }
    }
  }

  private func createPasskeySignIn() async -> SignIn? {
    do {
      return try await clerk.auth.createPasskeySignIn()
    } catch {
      if Task.isCancelled || error.isCancellationError { return nil }
      guard navigation.path.isEmpty else { return nil }

      generalError = error
      ClerkLogger.error("Failed to create passkey sign-in", error: error)
      return nil
    }
  }

  @discardableResult
  private func authenticateWithPasskey(
    signIn: SignIn,
    autofill: Bool,
    preferImmediatelyAvailableCredentials: Bool
  ) async -> PasskeySignInResult {
    do {
      let signIn = try await signIn.authenticateWithPasskey(
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
    let checkpoint = authState.environmentRefreshCheckpoint(for: clerk)
    guard let environment = try? await clerk.ensureEnvironmentRefreshed(after: checkpoint) else { return }
    guard !Task.isCancelled, navigation.path.isEmpty else { return }
    if includeAutomaticModal {
      automaticPasskeySignInHasStarted = true
    }

    let shouldPresentAutomaticModal = includeAutomaticModal && passkeyAutomaticModalIsEnabled(environment: environment)
    let shouldStartAutoFillFallback = passkeyAutoFillFallbackIsEnabled(environment: environment)
    guard shouldPresentAutomaticModal || shouldStartAutoFillFallback else { return }

    guard let signIn = await createPasskeySignIn() else { return }
    guard !Task.isCancelled, navigation.path.isEmpty else { return }

    if shouldPresentAutomaticModal {
      let result = await authenticateWithPasskey(
        signIn: signIn,
        autofill: false,
        preferImmediatelyAvailableCredentials: true
      )
      guard case .continueWithAutofill = result else { return }
    }

    guard shouldStartAutoFillFallback, navigation.path.isEmpty else { return }
    // Clerk's AutoFill setting gates the automatic modal above; this keeps
    // iOS text-field AutoFill available when a visible identifier field can
    // surface suggestions.
    await authenticateWithPasskey(
      signIn: signIn,
      autofill: true,
      preferImmediatelyAvailableCredentials: true
    )
  }
  #endif

  private func signUp() async -> Bool {
    fieldError = nil

    do {
      let signUp = try await signUpParams()
      navigation.setToStepForStatus(signUp: signUp)
      return signUpStatusStaysOnStart(signUp.status)
    } catch {
      fieldError = error
      return true
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

  private func signInStatusStaysOnStart(_ status: SignIn.Status) -> Bool {
    switch status {
    case .needsIdentifier, .unknown:
      true
    default:
      false
    }
  }

  private func signUpStatusStaysOnStart(_ status: SignUp.Status) -> Bool {
    switch status {
    case .abandoned, .unknown:
      true
    default:
      false
    }
  }

  #if os(iOS)
  private func refreshTrustedDeviceAvailability() async {
    guard authState.mode != .signUp, trustedDeviceFeatureIsEnabled else {
      trustedDeviceAvailability = nil
      return
    }

    trustedDeviceAvailability = try? await clerk.trustedDevices.availability(
      identifierHint: trustedDeviceIdentifierHint
    )
  }

  private func signInWithTrustedDevice() async {
    generalError = nil

    do {
      let signIn = try await clerk.trustedDevices.signIn(
        identifierHint: trustedDeviceIdentifierHint
      )
      navigation.setToStepForStatus(signIn: signIn)
    } catch {
      if error.isUserCancelledError {
        return
      }

      generalError = error
      await refreshTrustedDeviceAvailability()
    }
  }
  #endif
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
