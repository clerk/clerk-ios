//
//  Session+Verification.swift
//

#if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
import AuthenticationServices
#endif
import Foundation

extension Session {
  // MARK: - Reverification (Step-up)

  /// Starts an in-session reverification (step-up) flow.
  ///
  /// Use this when your backend has indicated that the current session's first factor is too
  /// old and a fresh factor is required to perform a sensitive action. After completing the
  /// returned verification, refresh the session token (for example with ``getToken(_:)``
  /// using ``GetTokenOptions/skipCache``) so subsequent API calls carry an updated first-factor
  /// age claim.
  ///
  /// - Parameter level: The verification level to request.
  /// - Returns: A ``SessionVerification`` reflecting the current state of the flow.
  @discardableResult @MainActor
  public func startVerification(level: SessionVerification.Level) async throws -> SessionVerification {
    try await Clerk.shared.dependencies.sessionService.startVerification(
      sessionId: id,
      params: .init(level: level)
    )
  }

  // MARK: - First factor verification

  /// Sends a verification code to the email address for first-factor reverification.
  @discardableResult @MainActor
  public func sendEmailCode(emailAddressId: String) async throws -> SessionVerification {
    try await prepareFirstFactorVerification(strategy: .emailCode, emailAddressId: emailAddressId)
  }

  /// Sends a verification code to the phone number for first-factor reverification.
  @discardableResult @MainActor
  public func sendPhoneCode(phoneNumberId: String) async throws -> SessionVerification {
    try await prepareFirstFactorVerification(strategy: .phoneCode, phoneNumberId: phoneNumberId)
  }

  /// Verifies the current session with an email code.
  @discardableResult @MainActor
  public func verifyWithEmailCode(code: String) async throws -> SessionVerification {
    try await attemptFirstFactorVerification(strategy: .emailCode, code: code)
  }

  /// Verifies the current session with a phone code as a first factor.
  @discardableResult @MainActor
  public func verifyWithPhoneCode(code: String) async throws -> SessionVerification {
    try await attemptFirstFactorVerification(strategy: .phoneCode, code: code)
  }

  /// Verifies the current session by asking the user to re-enter their password.
  @discardableResult @MainActor
  public func verifyWithPassword(_ password: String) async throws -> SessionVerification {
    try await attemptFirstFactorVerification(strategy: .password, password: password)
  }

  /// Starts Enterprise SSO for first-factor reverification.
  @discardableResult @MainActor
  public func startEnterpriseSSO(
    emailAddressId: String? = nil,
    enterpriseConnectionId: String? = nil,
    redirectUrl: String? = nil
  ) async throws -> SessionVerification {
    try await prepareFirstFactorVerification(
      strategy: .enterpriseSSO,
      emailAddressId: emailAddressId,
      enterpriseConnectionId: enterpriseConnectionId,
      redirectUrl: redirectUrl ?? Clerk.shared.options.redirectConfig.redirectUrl
    )
  }

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  /// Verifies the current session with a passkey.
  ///
  /// This convenience method prepares the passkey first-factor verification, requests the
  /// platform credential, and attempts the verification in a single call.
  ///
  /// - Parameter preferImmediatelyAvailableCredentials: Whether to prefer immediately
  ///   available credentials (default is `true`).
  /// - Returns: The resulting ``SessionVerification``.
  @discardableResult @MainActor
  public func verifyWithPasskey(
    preferImmediatelyAvailableCredentials: Bool = true
  ) async throws -> SessionVerification {
    let prepared = try await prepareFirstFactorVerification(strategy: .passkey)

    guard
      let nonceJSON = prepared.firstFactorVerification?.nonce?.toJSON(),
      let challengeString = nonceJSON["challenge"]?.stringValue,
      let challenge = challengeString.dataFromBase64URL()
    else {
      throw ClerkClientError(message: "Unable to get the challenge for the passkey.")
    }

    let manager = PasskeyHelper()
    let authorization = try await manager.signIn(
      challenge: challenge,
      preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
    )

    guard
      let credentialAssertion = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion,
      let authenticatorData = credentialAssertion.rawAuthenticatorData
    else {
      throw ClerkClientError(message: "Invalid credential type.")
    }

    let publicKeyCredential: [String: Any] = [
      "id": credentialAssertion.credentialID.base64EncodedString().base64URLFromBase64String(),
      "rawId": credentialAssertion.credentialID.base64EncodedString().base64URLFromBase64String(),
      "type": "public-key",
      "response": [
        "authenticatorData": authenticatorData.base64EncodedString().base64URLFromBase64String(),
        "clientDataJSON": credentialAssertion.rawClientDataJSON.base64EncodedString().base64URLFromBase64String(),
        "signature": credentialAssertion.signature.base64EncodedString().base64URLFromBase64String(),
        "userHandle": credentialAssertion.userID.base64EncodedString().base64URLFromBase64String(),
      ],
    ]

    let jsonData = try JSONSerialization.data(withJSONObject: publicKeyCredential, options: [])
    let credentialString = String(data: jsonData, encoding: .utf8) ?? ""

    return try await attemptFirstFactorVerification(
      strategy: .passkey,
      publicKeyCredential: credentialString
    )
  }
  #endif

  // MARK: - Second factor verification

  /// Sends an MFA code to the phone number for second-factor reverification.
  @discardableResult @MainActor
  public func sendMfaPhoneCode(phoneNumberId: String) async throws -> SessionVerification {
    try await prepareSecondFactorVerification(strategy: .phoneCode, phoneNumberId: phoneNumberId)
  }

  /// Verifies the current session with a phone code as a second factor.
  @discardableResult @MainActor
  public func verifyWithMfaPhoneCode(code: String) async throws -> SessionVerification {
    try await attemptSecondFactorVerification(strategy: .phoneCode, code: code)
  }

  /// Verifies the current session with a TOTP code.
  @discardableResult @MainActor
  public func verifyWithTOTP(code: String) async throws -> SessionVerification {
    try await attemptSecondFactorVerification(strategy: .totp, code: code)
  }

  /// Verifies the current session with a backup code.
  @discardableResult @MainActor
  public func verifyWithBackupCode(code: String) async throws -> SessionVerification {
    try await attemptSecondFactorVerification(strategy: .backupCode, code: code)
  }

  // MARK: - Internal helpers

  /// Prepares the first factor of an in-session reverification flow.
  @discardableResult @MainActor
  func prepareFirstFactorVerification(
    strategy: FactorStrategy,
    emailAddressId: String? = nil,
    phoneNumberId: String? = nil,
    enterpriseConnectionId: String? = nil,
    redirectUrl: String? = nil
  ) async throws -> SessionVerification {
    try await Clerk.shared.dependencies.sessionService.prepareFirstFactorVerification(
      sessionId: id,
      params: .init(
        strategy: strategy,
        emailAddressId: emailAddressId,
        phoneNumberId: phoneNumberId,
        enterpriseConnectionId: enterpriseConnectionId,
        redirectUrl: redirectUrl
      )
    )
  }

  /// Attempts the first factor of an in-session reverification flow.
  @discardableResult @MainActor
  func attemptFirstFactorVerification(
    strategy: FactorStrategy,
    code: String? = nil,
    password: String? = nil,
    publicKeyCredential: String? = nil
  ) async throws -> SessionVerification {
    try await Clerk.shared.dependencies.sessionService.attemptFirstFactorVerification(
      sessionId: id,
      params: .init(
        strategy: strategy,
        code: code,
        password: password,
        publicKeyCredential: publicKeyCredential
      )
    )
  }

  /// Prepares the second factor of an in-session reverification flow.
  @discardableResult @MainActor
  func prepareSecondFactorVerification(
    strategy: FactorStrategy,
    phoneNumberId: String? = nil
  ) async throws -> SessionVerification {
    try await Clerk.shared.dependencies.sessionService.prepareSecondFactorVerification(
      sessionId: id,
      params: .init(strategy: strategy, phoneNumberId: phoneNumberId)
    )
  }

  /// Attempts the second factor of an in-session reverification flow.
  @discardableResult @MainActor
  func attemptSecondFactorVerification(
    strategy: FactorStrategy,
    code: String
  ) async throws -> SessionVerification {
    try await Clerk.shared.dependencies.sessionService.attemptSecondFactorVerification(
      sessionId: id,
      params: .init(strategy: strategy, code: code)
    )
  }
}
