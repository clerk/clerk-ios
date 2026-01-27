//
//  SignIn.swift
//
//
//  Created by Mike Pitre on 1/30/24.
//

// swiftlint:disable file_length

import AuthenticationServices
import Foundation

/// The `SignIn` object holds the state of the current sign-in process and provides helper methods
/// to manage verification and session creation.
public struct SignIn: Codable, Sendable, Equatable {
  /// Unique identifier for this sign in.
  public var id: String

  /// The status of the current sign-in.
  ///
  /// See ``SignIn/Status-swift.enum`` for supported values.
  public var status: Status

  /// Array of all the authentication identifiers that are supported for this sign in.
  public var supportedIdentifiers: [Identifier]?

  /// The authentication identifier value for the current sign-in.
  public var identifier: String?

  /// Array of the first factors that are supported in the current sign-in.
  ///
  ///  Each factor contains information about the verification strategy that can be used. See the `SignInFirstFactor` type reference for more information.
  public var supportedFirstFactors: [Factor]?

  /// Array of the second factors that are supported in the current sign-in.
  ///
  /// Each factor contains information about the verification strategy that can be used. This property is populated only when the first factor is verified. See the `SignInSecondFactor` type reference for more information.
  public var supportedSecondFactors: [Factor]?

  /// The state of the verification process for the selected first factor.
  ///
  /// Initially, this property contains an empty verification object, since there is no first factor selected. You need to call the `prepareFirstFactor` method in order to start the verification process.
  public var firstFactorVerification: Verification?

  /// The state of the verification process for the selected second factor.
  ///
  /// Initially, this property contains an empty verification object, since there is no second factor selected. For the `phone_code` strategy, you need to call the `prepareSecondFactor` method in order to start the verification process. For the `totp` strategy, you can directly attempt.
  public var secondFactorVerification: Verification?

  /// An object containing information about the user of the current sign-in.
  ///
  /// This property is populated only once an identifier is given to the SignIn object.
  public var userData: UserData?

  /// The identifier of the session that was created upon completion of the current sign-in.
  ///
  /// The value of this property is `nil` if the sign-in status is not `complete`.
  public var createdSessionId: String?

  public init(
    id: String,
    status: SignIn.Status,
    supportedIdentifiers: [SignIn.Identifier]? = nil,
    identifier: String? = nil,
    supportedFirstFactors: [Factor]? = nil,
    supportedSecondFactors: [Factor]? = nil,
    firstFactorVerification: Verification? = nil,
    secondFactorVerification: Verification? = nil,
    userData: SignIn.UserData? = nil,
    createdSessionId: String? = nil
  ) {
    self.id = id
    self.status = status
    self.supportedIdentifiers = supportedIdentifiers
    self.identifier = identifier
    self.supportedFirstFactors = supportedFirstFactors
    self.supportedSecondFactors = supportedSecondFactors
    self.firstFactorVerification = firstFactorVerification
    self.secondFactorVerification = secondFactorVerification
    self.userData = userData
    self.createdSessionId = createdSessionId
  }
}

extension SignIn {
  @MainActor
  private var signInService: any SignInServiceProtocol { Clerk.shared.dependencies.signInService }

  // MARK: - First Factor Verification

  /// Sends a verification code to the specified email address.
  ///
  /// - Parameter emailAddressId: Optional email address ID. If not provided, uses the identifying first factor.
  /// - Returns: An updated `SignIn` object with the verification process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendEmailCode(emailAddressId: String? = nil) async throws -> SignIn {
    let emailId = emailAddressId ?? identifyingFirstFactor(for: "email_code")?.emailAddressId
    return try await signInService.prepareFirstFactor(
      signInId: id,
      params: .init(strategy: .emailCode, emailAddressId: emailId)
    )
  }

  /// Sends a verification code to the specified phone number.
  ///
  /// - Parameter phoneNumberId: Optional phone number ID. If not provided, uses the identifying first factor.
  /// - Returns: An updated `SignIn` object with the verification process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendPhoneCode(phoneNumberId: String? = nil) async throws -> SignIn {
    let phoneId = phoneNumberId ?? identifyingFirstFactor(for: "phone_code")?.phoneNumberId
    return try await signInService.prepareFirstFactor(
      signInId: id,
      params: .init(strategy: .phoneCode, phoneNumberId: phoneId)
    )
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
    let strategy = firstFactorVerification?.strategy ?? .emailCode
    return try await signInService.attemptFirstFactor(
      signInId: id,
      params: .init(strategy: strategy, code: code)
    )
  }

  /// Authenticates with the user's password.
  ///
  /// - Parameter password: The user's password.
  /// - Returns: An updated `SignIn` object reflecting the authentication result.
  /// - Throws: An error if password authentication fails.
  @discardableResult
  @MainActor
  public func authenticateWithPassword(_ password: String) async throws -> SignIn {
    try await signInService.attemptFirstFactor(
      signInId: id,
      params: .init(strategy: .password, password: password)
    )
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
    try await signInService.attemptFirstFactor(
      signInId: id,
      params: .init(strategy: .idToken(provider), token: idToken)
    )
  }

  /// Authenticates with Apple using Sign in with Apple.
  ///
  /// This method handles the entire Sign in with Apple flow for an existing sign-in, including:
  /// - Requesting Apple ID credentials
  /// - Extracting the ID token
  /// - Attempting authentication with the existing sign-in
  /// - Handling the transfer flow if needed
  ///
  /// - Parameters:
  ///   - requestedScopes: The scopes to request from Apple (defaults to `[.email, .fullName]`).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the authentication fails.
  @discardableResult
  @MainActor
  public func authenticateWithApple(requestedScopes: [ASAuthorization.Scope] = [.email, .fullName]) async throws -> TransferFlowResult {
    let credential = try await SignInWithAppleHelper.getAppleIdCredential(requestedScopes: requestedScopes)

    guard let idToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
      throw ClerkClientError(message: "Unable to retrieve the Apple identity token.")
    }

    let signIn = try await authenticateWithIdToken(idToken, provider: .apple)
    return try await signIn.handleTransferFlow()
  }
  #endif

  // MARK: - Second Factor Verification (MFA)

  /// Sends an MFA code to the phone number.
  ///
  /// - Parameter phoneNumberId: Optional phone number ID. If not provided, uses the identifying second factor.
  /// - Returns: An updated `SignIn` object with the MFA verification process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendMfaPhoneCode(phoneNumberId: String? = nil) async throws -> SignIn {
    let phoneId = phoneNumberId ?? identifyingSecondFactor(for: "phone_code")?.phoneNumberId
    return try await signInService.prepareSecondFactor(
      signInId: id,
      params: .init(strategy: .phoneCode, phoneNumberId: phoneId)
    )
  }

  /// Sends an MFA code to the email address.
  ///
  /// - Parameter emailAddressId: Optional email address ID. If not provided, uses the identifying second factor.
  /// - Returns: An updated `SignIn` object with the MFA verification process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendMfaEmailCode(emailAddressId: String? = nil) async throws -> SignIn {
    let emailId = emailAddressId ?? identifyingSecondFactor(for: "email_code")?.emailAddressId
    return try await signInService.prepareSecondFactor(
      signInId: id,
      params: .init(strategy: .emailCode, emailAddressId: emailId)
    )
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
    try await signInService.attemptSecondFactor(
      signInId: id,
      params: .init(strategy: type.strategy, code: code)
    )
  }

  // MARK: - Password Reset

  /// Sends a password reset code to the specified email address.
  ///
  /// - Parameter emailAddressId: Optional email address ID. If not provided, uses the identifying first factor.
  /// - Returns: An updated `SignIn` object with the password reset process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendResetPasswordEmailCode(emailAddressId: String? = nil) async throws -> SignIn {
    let emailId = emailAddressId ?? identifyingFirstFactor(for: "reset_password_email_code")?.emailAddressId
    return try await signInService.prepareFirstFactor(
      signInId: id,
      params: .init(strategy: .resetPasswordEmailCode, emailAddressId: emailId)
    )
  }

  /// Sends a password reset code to the specified phone number.
  ///
  /// - Parameter phoneNumberId: Optional phone number ID. If not provided, uses the identifying first factor.
  /// - Returns: An updated `SignIn` object with the password reset process started.
  /// - Throws: An error if sending the code fails.
  @discardableResult
  @MainActor
  public func sendResetPasswordPhoneCode(phoneNumberId: String? = nil) async throws -> SignIn {
    let phoneId = phoneNumberId ?? identifyingFirstFactor(for: "reset_password_phone_code")?.phoneNumberId
    return try await signInService.prepareFirstFactor(
      signInId: id,
      params: .init(strategy: .resetPasswordPhoneCode, phoneNumberId: phoneId)
    )
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
    try await signInService.resetPassword(
      signInId: id,
      params: .init(password: newPassword, signOutOfOtherSessions: signOutOfOtherSessions)
    )
  }

  // MARK: - Enterprise SSO

  #if !os(tvOS) && !os(watchOS)
  /// Authenticates with Enterprise SSO.
  ///
  /// This method prepares the enterprise SSO first factor and initiates the redirect flow.
  /// After the user completes authentication with their identity provider, the callback URL
  /// is handled automatically.
  ///
  /// - Parameter prefersEphemeralWebBrowserSession: Whether to use an ephemeral web browser session (default is `false`).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the enterprise SSO flow fails.
  @discardableResult
  @MainActor
  public func authenticateWithEnterpriseSSO(prefersEphemeralWebBrowserSession: Bool = false) async throws -> TransferFlowResult {
    let signIn = try await signInService.prepareFirstFactor(
      signInId: id,
      params: .init(
        strategy: .enterpriseSSO,
        redirectUrl: Clerk.shared.options.redirectConfig.redirectUrl
      )
    )

    guard let externalVerificationRedirectUrl = signIn.firstFactorVerification?.externalVerificationRedirectUrl,
          let url = URL(string: externalVerificationRedirectUrl)
    else {
      throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
    }

    let authSession = WebAuthentication(
      url: url,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
    )
    let callbackUrl = try await authSession.start()
    return try await signIn.handleRedirectCallbackUrl(callbackUrl)
  }

  /// Authenticates with OAuth using the specified provider.
  ///
  /// This method prepares the OAuth first factor and initiates the redirect flow.
  /// After the user completes authentication with the OAuth provider, the callback URL
  /// is handled automatically.
  ///
  /// - Parameters:
  ///   - provider: The OAuth provider to use (e.g., `.google`, `.github`).
  ///   - prefersEphemeralWebBrowserSession: Whether to use an ephemeral web browser session (default is `false`).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the OAuth flow fails.
  @discardableResult
  @MainActor
  public func authenticateWithOAuth(provider: OAuthProvider, prefersEphemeralWebBrowserSession: Bool = false) async throws -> TransferFlowResult {
    let signIn = try await signInService.prepareFirstFactor(
      signInId: id,
      params: .init(
        strategy: .oauth(provider),
        redirectUrl: Clerk.shared.options.redirectConfig.redirectUrl
      )
    )

    guard let externalVerificationRedirectUrl = signIn.firstFactorVerification?.externalVerificationRedirectUrl,
          let url = URL(string: externalVerificationRedirectUrl)
    else {
      throw ClerkClientError(message: "Redirect URL is missing or invalid. Unable to start external authentication flow.")
    }

    let authSession = WebAuthentication(
      url: url,
      prefersEphemeralWebBrowserSession: prefersEphemeralWebBrowserSession
    )
    let callbackUrl = try await authSession.start()
    return try await signIn.handleRedirectCallbackUrl(callbackUrl)
  }
  #endif

  // MARK: - Passkey

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  /// Authenticates with a passkey.
  ///
  /// This method prepares the passkey first factor, gets the credential from the device,
  /// and completes the authentication flow.
  ///
  /// - Parameters:
  ///   - autofill: Whether to use autofill-assisted flow (default is `false`).
  ///   - preferImmediatelyAvailableCredentials: Whether to prefer immediately available credentials (default is `true`).
  /// - Returns: An updated `SignIn` object reflecting the authentication result.
  /// - Throws: An error if passkey authentication fails.
  @discardableResult
  @MainActor
  public func authenticateWithPasskey(autofill: Bool = false, preferImmediatelyAvailableCredentials: Bool = true) async throws -> SignIn {
    let signIn = try await signInService.prepareFirstFactor(
      signInId: id,
      params: .init(strategy: .passkey, redirectUrl: Clerk.shared.options.redirectConfig.redirectUrl)
    )

    let credential = try await signIn.getCredentialForPasskey(
      autofill: autofill,
      preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
    )

    return try await signInService.attemptFirstFactor(
      signInId: signIn.id,
      params: .init(strategy: .passkey, publicKeyCredential: credential)
    )
  }
  #endif
}

extension SignIn {
  // MARK: - Internal Helpers

  /// Reloads the current sign-in state from the server.
  ///
  /// - Parameter rotatingTokenNonce: Optional rotating token nonce for reloading.
  /// - Returns: An updated `SignIn` object with the latest state.
  /// - Throws: An error if reloading fails.
  @discardableResult
  @MainActor
  func reload(rotatingTokenNonce: String? = nil) async throws -> SignIn {
    try await signInService.get(signInId: id, params: .init(rotatingTokenNonce: rotatingTokenNonce))
  }

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  /// Gets the credential for passkey authentication.
  ///
  /// - Parameters:
  ///   - autofill: Whether to use autofill-assisted flow (default is `false`).
  ///   - preferImmediatelyAvailableCredentials: Whether to prefer immediately available credentials (default is `true`).
  /// - Returns: A JSON-encoded string containing the passkey credential.
  /// - Throws: An error if getting the credential fails.
  @MainActor
  func getCredentialForPasskey(autofill: Bool = false, preferImmediatelyAvailableCredentials: Bool = true) async throws -> String {
    guard
      let nonceJSON = firstFactorVerification?.nonce?.toJSON(),
      let challengeString = nonceJSON["challenge"]?.stringValue,
      let challenge = challengeString.dataFromBase64URL()
    else {
      throw ClerkClientError(message: "Unable to get the challenge for the passkey.")
    }

    let manager = PasskeyHelper()
    let authorization: ASAuthorization

    #if os(iOS) && !targetEnvironment(macCatalyst)
    if autofill {
      authorization = try await manager.beginAutoFillAssistedPasskeySignIn(challenge: challenge)
    } else {
      authorization = try await manager.signIn(
        challenge: challenge,
        preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
      )
    }
    #else
    authorization = try await manager.signIn(
      challenge: challenge,
      preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
    )
    #endif

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

    let jsonData = try JSONSerialization.data(
      withJSONObject: publicKeyCredential,
      options: []
    )
    return String(
      data: jsonData,
      encoding: .utf8
    ) ?? ""
  }
  #endif

  /// Handles the callback url from external authentication. Determines whether to return a sign in or sign up.
  @discardableResult @MainActor
  func handleRedirectCallbackUrl(_ url: URL) async throws -> TransferFlowResult {
    if let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url) {
      let updatedSignIn = try await reload(rotatingTokenNonce: nonce)
      if let error = updatedSignIn.firstFactorVerification?.error {
        throw error
      }
      return .signIn(updatedSignIn)
    } else {
      // transfer flow
      let signIn = try await reload()
      let result = try await signIn.handleTransferFlow()
      switch result {
      case .signIn(let signIn):
        if let error = signIn.firstFactorVerification?.error {
          throw error
        }
      case .signUp(let signUp):
        if let verification = signUp.verifications.first(where: { $0.key == "external_account" })?.value,
           let error = verification.error
        {
          throw error
        }
      }
      return result
    }
  }

  /// Determines whether or not to return a sign in or sign up object as part of the transfer flow.
  @MainActor
  func handleTransferFlow() async throws -> TransferFlowResult {
    if needsTransferToSignUp == true {
      let signUpService: any SignUpServiceProtocol = Clerk.shared.dependencies.signUpService
      let signUp = try await signUpService.create(params: .init(transfer: true))
      return .signUp(signUp)
    } else {
      return .signIn(self)
    }
  }

  /// Helper to determine if the SignIn needs to be transferred to a SignUp
  var needsTransferToSignUp: Bool {
    firstFactorVerification?.status == .transferable || secondFactorVerification?.status == .transferable
  }

  /// The first factor matching the specified strategy string.
  package func identifyingFirstFactor(for strategy: String) -> Factor? {
    supportedFirstFactors?.first(where: { factor in
      factor.strategy.rawValue == strategy && factor.safeIdentifier == identifier
    })
  }

  /// The first factor matching the specified strategy string and identifier.
  package func identifyingFirstFactor(for strategy: String, matching identifier: String) -> Factor? {
    supportedFirstFactors?.first(where: { factor in
      factor.strategy.rawValue == strategy && factor.safeIdentifier == identifier
    })
  }

  /// The second factor matching the specified strategy string.
  func identifyingSecondFactor(for strategy: String) -> Factor? {
    supportedSecondFactors?.first(where: { factor in
      factor.strategy.rawValue == strategy && factor.safeIdentifier == identifier
    })
  }
}
