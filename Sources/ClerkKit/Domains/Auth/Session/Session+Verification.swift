//
//  Session+Verification.swift
//

#if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
import AuthenticationServices
#endif
import Foundation

extension Session {
  /// The factor stage a passkey should verify during session reverification.
  public enum PasskeyVerificationLevel: Sendable {
    /// Verifies the first-factor stage. Depending on instance configuration, a
    /// user-verified passkey may also satisfy an existing second-factor requirement.
    case firstFactor

    /// Verifies a second-factor stage that is already in progress.
    case secondFactor
  }

  /// The factor stage a biometric credential should verify during session reverification.
  public enum BiometricVerificationLevel: Sendable {
    /// Verifies the first factor and may satisfy an existing second-factor requirement.
    case firstFactor

    /// Verifies a second-factor stage that is already in progress.
    case secondFactor
  }

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

  /// Verifies the current session using a biometric credential enrolled on this app installation.
  ///
  /// Start the flow with ``startVerification(level:)`` and follow its returned status.
  /// A biometric credential submitted as the first factor can also satisfy an existing
  /// second-factor requirement. Use `.secondFactor` when the flow is waiting for that stage.
  ///
  /// Biometric reverification shares the instance's native biometric sign-in settings.
  /// Disabling biometric sign-in also disables biometric reverification, even for
  /// credentials that are already enrolled.
  ///
  /// - Parameters:
  ///   - reason: The explanation shown in the system biometric prompt.
  ///   - level: The factor stage to verify. Defaults to `.firstFactor`.
  /// - Returns: The resulting verification. On completion, cached tokens for this session
  ///   are cleared so the next token request includes the updated factor verification ages.
  @discardableResult @MainActor
  public func verifyWithBiometrics(
    reason: String? = nil,
    level: BiometricVerificationLevel = .firstFactor
  ) async throws -> SessionVerification {
    try await verifyWithBiometrics(
      reason: reason,
      level: level,
      biometricCredentials: Clerk.shared.biometricCredentials
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
  /// Verifies the first-factor stage of the current session with a passkey.
  ///
  /// Depending on instance configuration, a user-verified passkey may also satisfy an
  /// existing second-factor requirement and complete a multi-factor reverification.
  ///
  /// - Parameter preferImmediatelyAvailableCredentials: Whether to prefer immediately
  ///   available credentials (default is `true`).
  /// - Returns: The resulting ``SessionVerification``.
  @discardableResult @MainActor
  public func verifyWithPasskey(
    preferImmediatelyAvailableCredentials: Bool = true
  ) async throws -> SessionVerification {
    try await verifyWithPasskey(
      preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials,
      level: .firstFactor
    )
  }

  /// Verifies the requested factor stage of the current session with a passkey.
  ///
  /// Use `.secondFactor` only when the session verification is already waiting for its
  /// second factor. To begin a multi-factor reverification, call
  /// ``startVerification(level:)`` with `.multiFactor`, then follow the returned status.
  /// A passkey submitted as the first factor may satisfy both stages automatically.
  ///
  /// - Parameters:
  ///   - preferImmediatelyAvailableCredentials: Whether to prefer immediately available
  ///     credentials (default is `true`).
  ///   - level: The factor stage the passkey should verify.
  /// - Returns: The resulting ``SessionVerification``.
  @discardableResult @MainActor
  public func verifyWithPasskey(
    preferImmediatelyAvailableCredentials: Bool = true,
    level: PasskeyVerificationLevel
  ) async throws -> SessionVerification {
    let prepared =
      if level == .secondFactor {
        try await prepareSecondFactorVerification(strategy: .passkey)
      } else {
        try await prepareFirstFactorVerification(strategy: .passkey)
      }

    let verification =
      level == .secondFactor
        ? prepared.secondFactorVerification
        : prepared.firstFactorVerification

    let credentialString = try await passkeyCredential(
      for: verification,
      preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
    )

    if level == .secondFactor {
      return try await attemptSecondFactorVerification(
        strategy: .passkey,
        publicKeyCredential: credentialString
      )
    }

    return try await attemptFirstFactorVerification(strategy: .passkey, publicKeyCredential: credentialString)
  }

  @MainActor
  private func passkeyCredential(
    for verification: Verification?,
    preferImmediatelyAvailableCredentials: Bool
  ) async throws -> String {
    guard
      let nonceJSON = verification?.nonce?.toJSON(),
      let challengeString = nonceJSON["challenge"]?.stringValue,
      let challenge = challengeString.dataFromBase64URL()
    else {
      throw ClerkClientError(message: "Unable to get the challenge for the passkey.", localizationBundle: .module)
    }

    let relyingPartyIdentifier = nonceJSON.webAuthnAssertionRelyingPartyIdentifier
    let allowedCredentialIDs = nonceJSON.webAuthnAssertionAllowedCredentialIDs
    let manager = PasskeyHelper()
    let authorization = try await manager.signIn(
      challenge: challenge,
      relyingPartyIdentifier: relyingPartyIdentifier,
      allowedCredentialIDs: allowedCredentialIDs,
      preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
    )

    guard
      let credentialAssertion = authorization.credential as? ASAuthorizationPlatformPublicKeyCredentialAssertion,
      let authenticatorData = credentialAssertion.rawAuthenticatorData
    else {
      throw ClerkClientError(message: "Invalid credential type.", localizationBundle: .module)
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
    return String(data: jsonData, encoding: .utf8) ?? ""
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

  @MainActor
  func verifyWithBiometrics(
    reason: String? = nil,
    level: BiometricVerificationLevel = .firstFactor,
    biometricCredentials: BiometricCredentials
  ) async throws -> SessionVerification {
    // Reverification responses omit the user from their embedded session.
    let userID = user?.id ?? Clerk.shared.client?.sessions.first(where: { $0.id == id })?.user?.id
    guard status.allowsBiometricCredentialEnrollment, let userID else {
      throw ClerkClientError(message: "Biometric reverification requires an active or pending session with a user.")
    }

    let localCredential = try biometricCredentials.localCredential(for: userID)

    let service = Clerk.shared.dependencies.sessionService
    do {
      try _Concurrency.Task.checkCancellation()
      let prepared = if level == .secondFactor {
        try await service.prepareSecondFactorVerification(
          sessionId: id,
          params: .init(strategy: .biometricCredential, biometricCredentialId: localCredential.id)
        )
      } else {
        try await service.prepareFirstFactorVerification(
          sessionId: id,
          params: .init(strategy: .biometricCredential, biometricCredentialId: localCredential.id)
        )
      }
      let factor = level == .secondFactor ? prepared.secondFactorVerification : prepared.firstFactorVerification
      guard factor?.strategy == .biometricCredential,
            let challenge = factor?.biometricCredentialChallenge
      else {
        throw ClerkClientError(message: "Biometric reverification did not return a matching challenge.")
      }
      try _Concurrency.Task.checkCancellation()
      let signature = try biometricCredentials.sign(
        challenge: challenge,
        credential: localCredential,
        reason: reason ?? "Use biometrics to verify your identity."
      )
      try _Concurrency.Task.checkCancellation()
      let verified = if level == .secondFactor {
        try await service.attemptSecondFactorVerification(
          sessionId: id,
          params: .init(
            strategy: .biometricCredential,
            biometricCredentialId: localCredential.id,
            clientData: signature.clientData,
            signature: signature.signature,
            algorithm: signature.algorithm
          )
        )
      } else {
        try await service.attemptFirstFactorVerification(
          sessionId: id,
          params: .init(
            strategy: .biometricCredential,
            biometricCredentialId: localCredential.id,
            clientData: signature.clientData,
            signature: signature.signature,
            algorithm: signature.algorithm
          )
        )
      }
      if verified.status == .complete {
        await SessionTokensCache.shared.removeTokens(sessionId: id)
      }
      return verified
    } catch {
      throw biometricCredentials.handleBiometricCredentialError(error, localCredential: localCredential)
    }
  }

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
    code: String? = nil,
    publicKeyCredential: String? = nil
  ) async throws -> SessionVerification {
    try await Clerk.shared.dependencies.sessionService.attemptSecondFactorVerification(
      sessionId: id,
      params: .init(
        strategy: strategy,
        code: code,
        publicKeyCredential: publicKeyCredential
      )
    )
  }
}
