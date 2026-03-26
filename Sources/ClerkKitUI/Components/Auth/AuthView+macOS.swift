//
//  AuthView+macOS.swift
//  Clerk
//

#if os(macOS)

import ClerkKit
import SwiftUI

/// A minimal macOS authentication entry view for provider-based Clerk flows.
public struct AuthView: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.dismiss) private var dismiss
  @Environment(\.clerkTheme) private var theme

  @State private var authError: String?
  @State private var isAuthenticating = false
  @State private var clientTrustFactor: Factor?
  @State private var identifier = ""
  @State private var password = ""

  public enum Mode: String {
    case signInOrUp
    case signIn
    case signUp
  }

  let mode: Mode
  let isDismissable: Bool

  public init(mode: Mode = .signInOrUp, isDismissable: Bool = true) {
    self.mode = mode
    self.isDismissable = isDismissable
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      HStack(alignment: .top, spacing: 16) {
        VStack(alignment: .leading, spacing: 8) {
          Text(titleText)
            .font(theme.fonts.title2.weight(.semibold))
            .foregroundStyle(theme.colors.foreground)

          Text(subtitleText)
            .font(theme.fonts.body)
            .foregroundStyle(theme.colors.mutedForeground)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 0)

        if isDismissable {
          Button("Close") {
            dismiss()
          }
          .buttonStyle(.secondary(config: .init(emphasis: .low, size: .small)))
          .keyboardShortcut(.cancelAction)
        }
      }

      if isLoadingProviders {
        ClerkLoadingStatusView("Loading authentication options…")
      } else {
        VStack(alignment: .leading, spacing: 12) {
          if supportsPasswordSignIn {
            passwordSignInSection
          }

          if hasAlternativeAuthenticationMethods {
            if supportsPasswordSignIn {
              Text("Or continue with")
                .font(theme.fonts.footnote)
                .foregroundStyle(theme.colors.mutedForeground)
            }

            providerButtonsSection
          } else if !supportsPasswordSignIn {
            Text("No macOS-compatible authentication methods are currently enabled for this Clerk instance.")
              .font(theme.fonts.body)
              .foregroundStyle(theme.colors.mutedForeground)
          }
        }
      }

      if isAuthenticating {
        ClerkLoadingStatusView("Waiting for authentication…")
      }

      if let authError {
        Text(authError)
          .font(theme.fonts.footnote)
          .foregroundStyle(theme.colors.danger)
          .fixedSize(horizontal: false, vertical: true)
      }

      Text("This is the first macOS prebuilt auth entry surface. The broader signed-in profile UI remains separate work.")
        .font(theme.fonts.footnote)
        .foregroundStyle(theme.colors.mutedForeground)
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(24)
    .frame(minWidth: 420, maxWidth: 480, alignment: .leading)
    .background(theme.colors.background)
    .task {
      _ = try? await clerk.refreshEnvironment()
    }
    .sheet(
      isPresented: Binding(
        get: { clientTrustFactor != nil },
        set: { isPresented in
          if !isPresented {
            clientTrustFactor = nil
          }
        }
      )
    ) {
      if let clientTrustFactor {
        SignInClientTrustSheet(factor: clientTrustFactor)
      }
    }
  }
}

extension AuthView {
  fileprivate var passwordSignInSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(passwordSectionTitle)
        .font(theme.fonts.headline)
        .foregroundStyle(theme.colors.foreground)

      ClerkTextField(identifierPrompt, text: $identifier)

      ClerkTextField("Password", text: $password, isSecure: true)

      Button(passwordActionTitle) {
        Task {
          await authenticateWithPassword()
        }
      }
      .buttonStyle(.primary())
      .disabled(isAuthenticating || passwordSignInDisabled)
    }
  }

  fileprivate var providerButtonsSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      ForEach(socialProviderOptions, id: \.provider.strategy) { option in
        Button(actionTitle(for: option.name)) {
          Task {
            await authenticate(with: option.provider)
          }
        }
        .buttonStyle(.secondary(config: .init(emphasis: .low)))
        .disabled(isAuthenticating)
      }

      if showsPasskeyButton {
        Button(passkeyActionTitle) {
          Task {
            await authenticateWithPasskey()
          }
        }
        .buttonStyle(.secondary(config: .init(emphasis: .low)))
        .disabled(isAuthenticating)
      }
    }
  }
}

extension AuthView {
  private var titleText: String {
    switch mode {
    case .signInOrUp:
      "Continue with Clerk"
    case .signIn:
      "Sign in"
    case .signUp:
      "Create account"
    }
  }

  private var subtitleText: String {
    switch mode {
    case .signInOrUp:
      "Use a password or an enabled provider to sign in or create an account on macOS."
    case .signIn:
      "Use a password or an enabled provider to sign in on macOS."
    case .signUp:
      "Choose an enabled provider to create an account on macOS."
    }
  }

  private var isLoadingProviders: Bool {
    !clerk.isLoaded && clerk.environment == nil
  }

  private var socialProviderOptions: [(provider: OAuthProvider, name: String)] {
    guard let environment = clerk.environment else {
      return []
    }

    return environment.userSettings.social.values
      .filter { config in
        config.enabled && config.authenticatable && !config.notSelectable
      }
      .map { config in
        (provider: OAuthProvider(strategy: config.strategy), name: config.name)
      }
      .sorted { lhs, rhs in
        lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
      }
  }

  private var supportsPasswordSignIn: Bool {
    mode != .signUp &&
      clerk.environment?.passwordIsEnabled == true &&
      !identifierPrompt.isEmpty
  }

  private var hasAlternativeAuthenticationMethods: Bool {
    !socialProviderOptions.isEmpty || showsPasskeyButton
  }

  private var identifierPrompt: String {
    guard let environment = clerk.environment else {
      return ""
    }

    let supportsEmail = environment.enabledFirstFactorAttributes.contains("email_address")
    let supportsUsername = environment.enabledFirstFactorAttributes.contains("username")
    let supportsPhoneNumber = environment.enabledFirstFactorAttributes.contains("phone_number")

    switch (supportsEmail, supportsUsername, supportsPhoneNumber) {
    case (true, true, true):
      return "Email, username, or phone number"
    case (true, true, false):
      return "Email or username"
    case (true, false, true):
      return "Email or phone number"
    case (false, true, true):
      return "Username or phone number"
    case (true, false, false):
      return "Email"
    case (false, true, false):
      return "Username"
    case (false, false, true):
      return "Phone number"
    case (false, false, false):
      return ""
    }
  }

  private var passwordSectionTitle: String {
    switch mode {
    case .signInOrUp, .signIn:
      "Sign in with password"
    case .signUp:
      "Use password"
    }
  }

  private var passwordActionTitle: String {
    switch mode {
    case .signInOrUp:
      "Continue with password"
    case .signIn:
      "Sign in with password"
    case .signUp:
      "Use password"
    }
  }

  private var passwordSignInDisabled: Bool {
    identifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
      password.isEmpty
  }

  private var showsPasskeyButton: Bool {
    mode != .signUp && (clerk.environment?.userSettings.passkeySettings?.showSignInButton ?? false)
  }

  private var passkeyActionTitle: String {
    switch mode {
    case .signUp:
      "Continue with Passkey"
    case .signInOrUp, .signIn:
      "Continue with Passkey"
    }
  }

  private func actionTitle(for providerName: String) -> String {
    switch mode {
    case .signInOrUp:
      "Continue with \(providerName)"
    case .signIn:
      "Sign in with \(providerName)"
    case .signUp:
      "Sign up with \(providerName)"
    }
  }

  @MainActor
  private func authenticate(with provider: OAuthProvider) async {
    isAuthenticating = true
    authError = nil
    defer { isAuthenticating = false }

    do {
      let result: TransferFlowResult = switch (mode, provider) {
      case (.signUp, .apple):
        try await clerk.auth.signUpWithApple()
      case (.signUp, _):
        try await clerk.auth.signUpWithOAuth(provider: provider)
      case (.signIn, .apple):
        try await clerk.auth.signInWithApple(transferable: false)
      case (.signIn, _):
        try await clerk.auth.signInWithOAuth(provider: provider, transferable: false)
      case (_, .apple):
        try await clerk.auth.signInWithApple()
      default:
        try await clerk.auth.signInWithOAuth(provider: provider)
      }

      await handleTransferFlowResult(result)
    } catch {
      authError = error.localizedDescription
    }
  }

  @MainActor
  private func authenticateWithPassword() async {
    isAuthenticating = true
    authError = nil
    defer { isAuthenticating = false }

    do {
      let normalizedIdentifier = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
      let signIn = try await clerk.auth.signIn(normalizedIdentifier)
      let updatedSignIn = try await signIn.authenticateWithPassword(password)
      await handleSignInContinuation(updatedSignIn)
    } catch {
      authError = error.localizedDescription
    }
  }

  @MainActor
  private func authenticateWithPasskey() async {
    isAuthenticating = true
    authError = nil
    defer { isAuthenticating = false }

    do {
      _ = try await clerk.auth.signInWithPasskey()

      if isDismissable, clerk.session?.status == .active {
        dismiss()
      }
    } catch {
      authError = error.localizedDescription
    }
  }

  @MainActor
  private func handleTransferFlowResult(_ result: TransferFlowResult) async {
    switch result {
    case .signIn(let signIn):
      await handleSignInContinuation(signIn)
    case .signUp(let signUp):
      await handleSignUpContinuation(signUp)
    }
  }

  @MainActor
  private func handleSignInContinuation(_ signIn: SignIn) async {
    switch signIn.status {
    case .complete:
      await handleCompletedSignIn(signIn)
    case .needsSecondFactor:
      authError = "This account requires a second authentication step. The macOS follow-up UI for that step is not implemented yet."
    case .needsNewPassword:
      authError = "This account requires a password reset before sign-in can complete. The macOS password-reset continuation UI is not implemented yet."
    case .needsClientTrust:
      guard let factor = supportedClientTrustFactor(from: signIn) else {
        authError = "This account requires client trust verification with an unsupported method on macOS."
        return
      }

      clientTrustFactor = factor
    case .needsFirstFactor:
      authError = "Password sign-in could not be completed because another first-factor step is required."
    case .needsIdentifier:
      authError = "An account identifier is still required to continue sign-in."
    case .unknown:
      authError = "Sign-in returned an unsupported follow-up state on macOS."
    }
  }

  @MainActor
  private func handleSignUpContinuation(_ signUp: SignUp) async {
    switch signUp.status {
    case .complete:
      _ = try? await clerk.refreshClient()

      if let createdSessionId = signUp.createdSessionId,
         clerk.session?.id != createdSessionId
      {
        try? await clerk.auth.setActive(sessionId: createdSessionId)
      }

      if isDismissable, clerk.session?.status == .active {
        dismiss()
      }
    case .missingRequirements:
      authError = "This provider flow transferred to sign-up and requires additional fields that are not implemented in the macOS prebuilt auth flow yet."
    case .abandoned:
      authError = "This sign-up flow was abandoned before completion."
    case .unknown:
      authError = "Sign-up returned an unsupported follow-up state on macOS."
    }
  }

  @MainActor
  private func handleCompletedSignIn(_ signIn: SignIn) async {
    _ = try? await clerk.refreshClient()

    if let createdSessionId = signIn.createdSessionId,
       clerk.session?.id != createdSessionId
    {
      try? await clerk.auth.setActive(sessionId: createdSessionId)
    }

    if isDismissable, clerk.session?.status == .active {
      dismiss()
    }
  }

  private func supportedClientTrustFactor(from signIn: SignIn) -> Factor? {
    if let phoneCodeFactor = signIn.supportedSecondFactors?.first(where: { $0.strategy == .phoneCode }) {
      return phoneCodeFactor
    }

    if let emailCodeFactor = signIn.supportedSecondFactors?.first(where: { $0.strategy == .emailCode }) {
      return emailCodeFactor
    }

    return nil
  }
}

private struct SignInClientTrustSheet: View {
  @Environment(Clerk.self) private var clerk
  @Environment(\.dismiss) private var dismiss
  @Environment(\.clerkTheme) private var theme

  let factor: Factor

  @State private var code = ""
  @State private var errorMessage: String?
  @State private var hasPrepared = false
  @State private var isPreparingCode = false
  @State private var isVerifying = false

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      Text("Verify this device")
        .font(theme.fonts.title3.weight(.semibold))
        .foregroundStyle(theme.colors.foreground)

      Text("You're signing in from a new device. Enter the verification code we send to continue.")
        .font(theme.fonts.body)
        .foregroundStyle(theme.colors.mutedForeground)
        .fixedSize(horizontal: false, vertical: true)

      if let destinationDescription {
        Text(destinationDescription)
          .font(theme.fonts.subheadline)
          .foregroundStyle(theme.colors.mutedForeground)
          .fixedSize(horizontal: false, vertical: true)
      }

      ClerkTextField("Verification code", text: $code)

      if isPreparingCode {
        ClerkLoadingStatusView("Sending code…")
      }

      if isVerifying {
        ClerkLoadingStatusView("Verifying…")
      }

      if let errorMessage {
        Text(errorMessage)
          .font(theme.fonts.footnote)
          .foregroundStyle(theme.colors.danger)
          .fixedSize(horizontal: false, vertical: true)
      }

      HStack {
        Button("Cancel") {
          dismiss()
        }
        .buttonStyle(.secondary(config: .init(emphasis: .low, size: .small)))
        .keyboardShortcut(.cancelAction)

        Spacer()

        Button("Resend Code") {
          Task {
            await prepareCode()
          }
        }
        .buttonStyle(.secondary(config: .init(emphasis: .low, size: .small)))
        .disabled(isPreparingCode || isVerifying)

        Button("Verify") {
          Task {
            await verifyCode()
          }
        }
        .buttonStyle(.primary())
        .disabled(code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isPreparingCode || isVerifying)
      }
    }
    .padding(24)
    .frame(minWidth: 420, maxWidth: 480, alignment: .leading)
    .background(theme.colors.background)
    .task {
      guard !hasPrepared else { return }
      hasPrepared = true
      await prepareCode()
    }
  }
}

extension SignInClientTrustSheet {
  fileprivate var destinationDescription: String? {
    guard let safeIdentifier = factor.safeIdentifier, !safeIdentifier.isEmpty else { return nil }

    switch factor.strategy {
    case .phoneCode:
      return "Code will be sent to \(safeIdentifier)."
    case .emailCode:
      return "Code will be sent to \(safeIdentifier)."
    default:
      return nil
    }
  }

  @MainActor
  fileprivate func prepareCode() async {
    guard var signIn = clerk.auth.currentSignIn else {
      errorMessage = "The sign-in attempt is no longer available."
      return
    }

    isPreparingCode = true
    errorMessage = nil
    defer { isPreparingCode = false }

    do {
      switch factor.strategy {
      case .emailCode:
        signIn = try await signIn.sendMfaEmailCode(emailAddressId: factor.emailAddressId)
      case .phoneCode:
        signIn = try await signIn.sendMfaPhoneCode(phoneNumberId: factor.phoneNumberId)
      default:
        errorMessage = "This client trust method is not supported on macOS yet."
        return
      }

      if let nextFactor = updatedClientTrustFactor(from: signIn) {
        _ = nextFactor
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  @MainActor
  fileprivate func verifyCode() async {
    guard let normalizedCode else { return }
    guard let signIn = clerk.auth.currentSignIn else {
      errorMessage = "The sign-in attempt is no longer available."
      return
    }

    isVerifying = true
    errorMessage = nil
    defer { isVerifying = false }

    do {
      let updatedSignIn: SignIn
      switch factor.strategy {
      case .emailCode:
        updatedSignIn = try await signIn.verifyMfaCode(normalizedCode, type: .emailCode)
      case .phoneCode:
        updatedSignIn = try await signIn.verifyMfaCode(normalizedCode, type: .phoneCode)
      default:
        errorMessage = "This client trust method is not supported on macOS yet."
        return
      }

      switch updatedSignIn.status {
      case .complete:
        _ = try? await clerk.refreshClient()

        if let createdSessionId = updatedSignIn.createdSessionId,
           clerk.session?.id != createdSessionId
        {
          try? await clerk.auth.setActive(sessionId: createdSessionId)
        }

        dismiss()
      case .needsClientTrust:
        errorMessage = "Client trust verification still needs another code step on macOS."
      case .needsSecondFactor:
        errorMessage = "This account now requires a second-factor step that is not implemented in the macOS add-account flow yet."
      case .needsNewPassword:
        errorMessage = "This account now requires a password reset before sign-in can complete."
      case .needsFirstFactor:
        errorMessage = "Sign-in moved back to a first-factor step that is not implemented in this macOS continuation flow."
      case .needsIdentifier:
        errorMessage = "The sign-in attempt is missing its identifier."
      case .unknown:
        errorMessage = "Sign-in returned an unsupported follow-up state on macOS."
      }
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  fileprivate var normalizedCode: String? {
    let normalizedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !normalizedCode.isEmpty else { return nil }
    return normalizedCode
  }

  fileprivate func updatedClientTrustFactor(from signIn: SignIn) -> Factor? {
    if let phoneCodeFactor = signIn.supportedSecondFactors?.first(where: { $0.strategy == .phoneCode }) {
      return phoneCodeFactor
    }

    if let emailCodeFactor = signIn.supportedSecondFactors?.first(where: { $0.strategy == .emailCode }) {
      return emailCodeFactor
    }

    return nil
  }
}
#endif
