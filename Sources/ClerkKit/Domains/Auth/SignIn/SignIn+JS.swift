import ClerkSnapshots
import Foundation

extension SignIn {
  @discardableResult
  @MainActor
  func reload(rotatingTokenNonce: String? = nil) async throws -> SignIn {
    try await Clerk.js(
      .signIn,
      SignInJSCall.reload(
        rotatingTokenNonce.map { ClerkResourceReloadParams(rotatingTokenNonce: $0) }
      )
    )
    return try Clerk.requireEngineSignIn()
  }

  /// Sends a verification code to the specified email address.
  ///
  /// - Parameter emailAddressId: Optional email address ID. If not provided, uses the identifying first factor.
  /// - Returns: An updated `SignIn` object with the verification process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendEmailCode(emailAddressId: String? = nil) async throws -> SignIn {
    try await Clerk.js(
      .signIn,
      SignInJSCall.prepareFirstFactor(
        ClerkSnapshots.PrepareFirstFactorParams(strategy: "email_code", emailAddressId: emailAddressId)
      )
    )
    return try Clerk.requireEngineSignIn()
  }

  /// Sends a native magic link to the specified email address.
  ///
  /// This prepares the `email_link` first factor using PKCE and stores the verifier locally
  /// so the callback can be completed inside the app. Only one pending native
  /// magic-link flow is stored locally at a time; starting a new flow replaces
  /// the previously stored verifier.
  ///
  /// - Parameters:
  ///   - emailAddressId: Optional email address ID. If not provided, uses the identifying email-link factor.
  ///   - redirectUri: Optional redirect URI override. Defaults to the Clerk redirect configuration.
  /// - Returns: An updated `SignIn` object with the email-link verification started.
  /// - Throws: An error if email-link sign-in is unavailable or preparation fails.
  @discardableResult
  @MainActor
  public func sendEmailLink(
    emailAddressId: String? = nil,
    redirectUri: String? = nil
  ) async throws -> SignIn {
    let emailId =
      emailAddressId
        ?? identifyingFirstFactor(for: FactorStrategy.emailLink.rawValue)?.emailAddressId
        ?? firstFactors.first(where: { $0.strategy == .emailLink })?.emailAddressId

    guard let emailId else {
      throw ClerkClientError(message: "Email link sign-in is not available for this sign-in.", localizationBundle: .module)
    }

    let resolvedRedirectUri = redirectUri ?? Clerk.shared.options.redirectConfig.redirectUrl
    guard !resolvedRedirectUri.isEmpty else {
      throw ClerkClientError(message: "Redirect URI is missing. Unable to start email link sign-in.", localizationBundle: .module)
    }

    let pkcePair = try PKCE.generatePair()
    try Clerk.shared.dependencies.magicLinkStore.save(
      kind: .signIn,
      flowId: id,
      codeVerifier: pkcePair.verifier,
      authFlowOwnerId: AuthFlowRequestScope.ownerId
    )

    try await Clerk.js(
      .signIn,
      SignInJSCall.prepareFirstFactor(
        ClerkSnapshots.PrepareFirstFactorParams(
          strategy: "email_link",
          emailAddressId: emailId,
          redirectUrl: resolvedRedirectUri,
          codeChallenge: pkcePair.challenge,
          codeChallengeMethod: PKCE.codeChallengeMethod
        )
      )
    )
    return try Clerk.requireEngineSignIn()
  }

  /// Sends a verification code to the specified phone number.
  ///
  /// - Parameter phoneNumberId: Optional phone number ID. If not provided, uses the identifying first factor.
  /// - Returns: An updated `SignIn` object with the verification process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendPhoneCode(phoneNumberId: String? = nil) async throws -> SignIn {
    try await Clerk.js(
      .signIn,
      SignInJSCall.prepareFirstFactor(
        ClerkSnapshots.PrepareFirstFactorParams(strategy: "phone_code", phoneNumberId: phoneNumberId)
      )
    )
    return try Clerk.requireEngineSignIn()
  }

  /// Verifies the code entered by the user.
  ///
  /// The verification strategy is inferred from the current `firstFactorVerification` state.
  ///
  /// - Parameter code: The verification code entered by the user.
  /// - Returns: An updated `SignIn` object reflecting the verification result.
  /// - Throws: An error if verification fails.
  @discardableResult
  @MainActor
  public func verifyCode(_ code: String) async throws -> SignIn {
    try await Clerk.js(
      .clerk,
      JSRawCall("verifyNativeSignInCode", .object(["expectedId": .string(id), "code": .string(code)]))
    )
    return try Clerk.requireEngineSignIn()
  }

  /// Authenticates with the user's password.
  ///
  /// - Parameter password: The user's password.
  /// - Returns: An updated `SignIn` object reflecting the authentication result.
  /// - Throws: An error if password authentication fails.
  @discardableResult
  @MainActor
  public func authenticateWithPassword(_ password: String) async throws -> SignIn {
    try await Clerk.js(
      .signIn,
      SignInJSCall.attemptFirstFactor(
        ClerkSnapshots.AttemptFirstFactorParams(strategy: .password, password: password)
      )
    )
    return try await Clerk.finishedSignIn()
  }

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  /// Authenticates with an ID token from a provider (e.g., Sign in with Apple).
  ///
  /// This method attempts first factor authentication using an ID token directly,
  /// without requiring a prepare step. This is useful for native authentication flows
  /// where you already have an ID token from the provider.
  ///
  /// - Parameters:
  ///   - idToken: The ID token from the provider.
  ///   - provider: The ID token provider (e.g., `.apple`).
  /// - Returns: An updated `SignIn` object reflecting the authentication result.
  /// - Throws: An error if authentication fails.
  @discardableResult
  @MainActor
  public func authenticateWithIdToken(_ idToken: String, provider: IDTokenProvider) async throws -> SignIn {
    try await Clerk.js(
      .signIn,
      JSRawCall(
        "attemptFirstFactor",
        JSONValue(encoding: IdTokenAttemptArgs(strategy: provider.strategy, token: idToken))
      )
    )
    return try await Clerk.finishedSignIn()
  }
  #endif

  /// Sends an MFA code to the phone number.
  ///
  /// - Parameter phoneNumberId: Optional phone number ID. If not provided, uses the identifying second factor.
  /// - Returns: An updated `SignIn` object with the MFA verification process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendMfaPhoneCode(phoneNumberId: String? = nil) async throws -> SignIn {
    try await Clerk.js(
      .signIn,
      SignInJSCall.prepareSecondFactor(
        ClerkSnapshots.PrepareSecondFactorParams(strategy: .phoneCode, phoneNumberId: phoneNumberId)
      )
    )
    return try Clerk.requireEngineSignIn()
  }

  /// Sends an MFA code to the email address.
  ///
  /// - Parameter emailAddressId: Optional email address ID. If not provided, uses the identifying second factor.
  /// - Returns: An updated `SignIn` object with the MFA verification process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendMfaEmailCode(emailAddressId: String? = nil) async throws -> SignIn {
    try await Clerk.js(
      .signIn,
      SignInJSCall.prepareSecondFactor(
        ClerkSnapshots.PrepareSecondFactorParams(strategy: .emailCode, emailAddressId: emailAddressId)
      )
    )
    return try Clerk.requireEngineSignIn()
  }

  /// Verifies the MFA code with the specified type.
  ///
  /// - Parameters:
  ///   - code: The MFA code entered by the user.
  ///   - type: The type of MFA verification (`.phoneCode`, `.emailCode`, `.totp`, or `.backupCode`).
  /// - Returns: An updated `SignIn` object reflecting the verification result.
  /// - Throws: An error if verification fails.
  @discardableResult
  @MainActor
  public func verifyMfaCode(_ code: String, type: MfaType) async throws -> SignIn {
    try await Clerk.js(
      .signIn,
      SignInJSCall.attemptSecondFactor(
        ClerkSnapshots.AttemptSecondFactorParams(strategy: type.attemptStrategy, code: code)
      )
    )
    return try await Clerk.finishedSignIn()
  }

  /// Sends a password reset code to the specified email address.
  ///
  /// - Parameter emailAddressId: Optional email address ID. If not provided, uses the identifying first factor.
  /// - Returns: An updated `SignIn` object with the password reset process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendResetPasswordEmailCode(emailAddressId: String? = nil) async throws -> SignIn {
    try await Clerk.js(
      .signIn,
      SignInJSCall.prepareFirstFactor(
        ClerkSnapshots.PrepareFirstFactorParams(
          strategy: "reset_password_email_code",
          emailAddressId: emailAddressId
        )
      )
    )
    return try Clerk.requireEngineSignIn()
  }

  /// Sends a password reset code to the specified phone number.
  ///
  /// - Parameter phoneNumberId: Optional phone number ID. If not provided, uses the identifying first factor.
  /// - Returns: An updated `SignIn` object with the password reset process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendResetPasswordPhoneCode(phoneNumberId: String? = nil) async throws -> SignIn {
    try await Clerk.js(
      .signIn,
      SignInJSCall.prepareFirstFactor(
        ClerkSnapshots.PrepareFirstFactorParams(
          strategy: "reset_password_phone_code",
          phoneNumberId: phoneNumberId
        )
      )
    )
    return try Clerk.requireEngineSignIn()
  }

  /// Resets the user's password after verification.
  ///
  /// - Parameters:
  ///   - newPassword: The new password to set.
  ///   - signOutOfOtherSessions: Whether to sign out of all other active sessions (default is `false`).
  /// - Returns: An updated `SignIn` object reflecting the password reset result.
  /// - Throws: An error if password reset fails.
  @discardableResult
  @MainActor
  public func resetPassword(newPassword: String, signOutOfOtherSessions: Bool = false) async throws -> SignIn {
    try await Clerk.js(
      .signIn,
      SignInJSCall.resetPassword(
        ClerkSnapshots.ResetPasswordParams(password: newPassword, signOutOfOtherSessions: signOutOfOtherSessions)
      )
    )
    return try await Clerk.finishedSignIn()
  }

  @MainActor
  func handleTransferFlow(
    transferable: Bool = true,
    unsafeMetadata: JSON? = nil
  ) async throws -> TransferFlowResult {
    try await Clerk.completeNativeAuth(flow: "signIn", expectedId: id, transferable: transferable, unsafeMetadata: unsafeMetadata)
  }
}

extension SignIn.MfaType {
  fileprivate var attemptStrategy: ClerkSnapshots.AttemptSecondFactorParamsStrategy {
    switch self {
    case .phoneCode:
      .phoneCode
    case .emailCode:
      .emailCode
    case .totp:
      .totp
    case .backupCode:
      .backupCode
    }
  }
}

private struct IdTokenAttemptArgs: Encodable {
  var strategy: String
  var token: String
}
