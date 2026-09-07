//
//  SignIn.swift
//

// swiftlint:disable file_length

import AuthenticationServices
import ClerkSnapshots
import Foundation

extension SignIn {
  #if !os(tvOS) && !os(watchOS)
  /// Completes enterprise SSO after your app receives the callback URL.
  ///
  /// This pairs with ``Auth/startEnterpriseSSO(emailAddress:redirectUrl:)`` when your app handles browser presentation itself.
  ///
  /// - Parameters:
  ///   - callbackURL: The callback URL your app received after the user completed enterprise SSO.
  ///   - transferable: Indicates whether a user should be signed up if they attempt to sign in but do not already have an account.
  ///     Defaults to `true`. When `false`, the flow returns `.signIn` and skips sign-up creation.
  ///   - unsafeMetadata: Custom metadata to attach if this flow creates a sign-up (optional).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if completing enterprise SSO fails.
  @discardableResult
  @MainActor
  public func completeEnterpriseSSO(
    callbackURL: URL,
    transferable: Bool = true,
    unsafeMetadata: JSON? = nil
  ) async throws -> TransferFlowResult {
    try await handleRedirectCallbackUrl(
      callbackURL,
      transferable: transferable,
      unsafeMetadata: unsafeMetadata
    )
  }
  #endif

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
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
  ///   - transferable: Indicates whether a user should be signed up if they attempt to sign in but do not already have an account.
  ///     Defaults to `true`. When `false`, the flow returns `.signIn` and skips sign-up creation.
  ///   - unsafeMetadata: Custom metadata to attach if this flow creates a sign-up (optional).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the authentication fails.
  @discardableResult
  @MainActor
  public func authenticateWithApple(
    requestedScopes: [ASAuthorization.Scope] = [.email, .fullName],
    transferable: Bool = true,
    unsafeMetadata: JSON? = nil
  ) async throws -> TransferFlowResult {
    let credential = try await SignInWithAppleHelper.getAppleIdCredential(requestedScopes: requestedScopes)

    guard let idToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8) }) else {
      throw ClerkClientError(message: "Unable to retrieve the Apple identity token.", localizationBundle: .module)
    }

    let signIn = try await authenticateWithIdToken(idToken, provider: .apple)
    let result = try await signIn.handleTransferFlow(
      transferable: transferable,
      unsafeMetadata: unsafeMetadata
    )
    if case .signIn(let signIn) = result, let error = signIn.firstFactorVerification?.kitError {
      throw error
    }
    return result
  }
  #endif

  // MARK: - Enterprise SSO

  #if !os(tvOS) && !os(watchOS)
  /// Authenticates with Enterprise SSO.
  ///
  /// This method prepares the enterprise SSO first factor and initiates the redirect flow.
  /// After the user completes authentication with their identity provider, the callback URL
  /// is handled automatically.
  ///
  /// - Parameters:
  ///   - prefersEphemeralWebBrowserSession: Whether to use an ephemeral web browser session (default is `false`).
  ///   - transferable: Indicates whether a user should be signed up if they attempt to sign in but do not already have an account.
  ///     Defaults to `true`. When `false`, the flow returns `.signIn` and skips sign-up creation.
  ///   - unsafeMetadata: Custom metadata to attach if this flow creates a sign-up (optional).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the enterprise SSO flow fails.
  @discardableResult
  @MainActor
  public func authenticateWithEnterpriseSSO(
    prefersEphemeralWebBrowserSession _: Bool = false,
    transferable _: Bool = true,
    unsafeMetadata _: JSON? = nil
  ) async throws -> TransferFlowResult {
    try await Clerk.authenticateWithRedirect(
      strategy: FactorStrategy.enterpriseSSO.rawValue,
      identifier: identifier
    )
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
  ///   - transferable: Indicates whether a user should be signed up if they attempt to sign in but do not already have an account.
  ///     Defaults to `true`. When `false`, the flow returns `.signIn` and skips sign-up creation.
  ///   - unsafeMetadata: Custom metadata to attach if this flow creates a sign-up (optional).
  /// - Returns: A `TransferFlowResult` that may contain a `SignIn` or `SignUp` depending on the flow.
  /// - Throws: An error if the OAuth flow fails.
  @discardableResult
  @MainActor
  public func authenticateWithOAuth(
    provider: OAuthProvider,
    prefersEphemeralWebBrowserSession _: Bool = false,
    transferable _: Bool = true,
    unsafeMetadata _: JSON? = nil
  ) async throws -> TransferFlowResult {
    try await Clerk.authenticateWithRedirect(strategy: provider.strategy, identifier: identifier)
  }
  #endif

  // MARK: - Passkey

  #if canImport(AuthenticationServices) && !os(watchOS) && !os(tvOS)
  /// Authenticates with a passkey.
  ///
  /// If this sign-in requires a second factor and advertises passkey support, this method reuses
  /// the in-progress sign-in and completes the passkey as its second factor. Otherwise, it prepares
  /// and attempts the passkey as the first factor.
  ///
  /// - Parameters:
  ///   - autofill: Whether to use autofill-assisted flow for a first factor (default is `false`).
  ///     This value is ignored when passkey is used as a second factor.
  ///   - preferImmediatelyAvailableCredentials: Whether to prefer immediately available credentials (default is `true`).
  /// - Returns: An updated `SignIn` object reflecting the authentication result.
  /// - Throws: An error if passkey authentication fails.
  @discardableResult
  @MainActor
  public func authenticateWithPasskey(autofill: Bool = false, preferImmediatelyAvailableCredentials: Bool = true) async throws -> SignIn {
    do {
      return try await authenticateWithPasskeyWithFailureContext(
        autofill: autofill,
        preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
      )
    } catch {
      throw error.underlyingError
    }
  }

  @discardableResult
  @MainActor
  package func authenticateWithPasskeyWithFailureContext(
    autofill: Bool = false,
    preferImmediatelyAvailableCredentials: Bool = true
  ) async throws(PasskeyAuthenticationFailure) -> SignIn {
    if !usesPasskeyAsSecondFactor {
      do {
        try await SignIn.authenticatePasskey(autofill: autofill)
        return try await Clerk.finishedSignIn()
      } catch {
        throw PasskeyAuthenticationFailure(stage: .attemptingFirstFactor, underlyingError: error)
      }
    }
    let usesSecondFactor = usesPasskeyAsSecondFactor
    return try await authenticateWithPasskeyWithFailureContext { signIn in
      try await signIn.getCredentialForPasskey(
        autofill: usesSecondFactor ? false : autofill,
        preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
      )
    }
  }

  @discardableResult
  @MainActor
  func authenticateWithPasskeyWithFailureContext(
    credentialProvider: @MainActor (SignIn) async throws -> String
  ) async throws(PasskeyAuthenticationFailure) -> SignIn {
    let usesSecondFactor = usesPasskeyAsSecondFactor
    let signIn: SignIn
    do {
      if usesSecondFactor {
        try await SignIn.preparePasskeySecondFactor()
      } else {
        try await SignIn.preparePasskeyFirstFactor()
      }
      signIn = try Clerk.requireEngineSignIn()
    } catch {
      throw PasskeyAuthenticationFailure(
        stage: usesSecondFactor ? .preparingSecondFactor : .preparingFirstFactor,
        underlyingError: error
      )
    }

    let credential: String
    do {
      credential = try await credentialProvider(signIn)
    } catch {
      throw PasskeyAuthenticationFailure(
        stage: .requestingAuthorization,
        underlyingError: error
      )
    }

    do {
      if usesSecondFactor {
        try await SignIn.attemptPasskeySecondFactor(credential: credential)
      } else {
        try await SignIn.attemptPasskeyFirstFactor(credential: credential)
      }
      return try Clerk.requireEngineSignIn()
    } catch {
      throw PasskeyAuthenticationFailure(
        stage: usesSecondFactor ? .attemptingSecondFactor : .attemptingFirstFactor,
        underlyingError: error
      )
    }
  }
  #endif
}

extension SignIn {
  // MARK: - Internal Helpers

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
    let verification =
      usesPasskeyAsSecondFactor
        ? secondFactorVerification
        : firstFactorVerification

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
    let authorization: ASAuthorization

    #if os(iOS) && !targetEnvironment(macCatalyst)
    if autofill {
      authorization = try await manager.beginAutoFillAssistedPasskeySignIn(
        challenge: challenge,
        relyingPartyIdentifier: relyingPartyIdentifier,
        allowedCredentialIDs: allowedCredentialIDs
      )
    } else {
      authorization = try await manager.signIn(
        challenge: challenge,
        relyingPartyIdentifier: relyingPartyIdentifier,
        allowedCredentialIDs: allowedCredentialIDs,
        preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
      )
    }
    #else
    authorization = try await manager.signIn(
      challenge: challenge,
      relyingPartyIdentifier: relyingPartyIdentifier,
      allowedCredentialIDs: allowedCredentialIDs,
      preferImmediatelyAvailableCredentials: preferImmediatelyAvailableCredentials
    )
    #endif

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
  func handleRedirectCallbackUrl(
    _ url: URL,
    transferable: Bool = true,
    unsafeMetadata: JSON? = nil
  ) async throws -> TransferFlowResult {
    if let nonce = ExternalAuthUtils.nonceFromCallbackUrl(url: url) {
      let updatedSignIn = try await reload(rotatingTokenNonce: nonce)
      if let error = updatedSignIn.firstFactorVerification?.kitError {
        throw error
      }
      return .signIn(updatedSignIn)
    } else {
      // transfer flow
      let signIn = try await reload()
      let result = try await signIn.handleTransferFlow(
        transferable: transferable,
        unsafeMetadata: unsafeMetadata
      )
      switch result {
      case .signIn(let signIn):
        if let error = signIn.firstFactorVerification?.kitError {
          throw error
        }
      case .signUp(let signUp):
        if let error = signUp.verificationByAttribute["external_account"]??.kitError {
          throw error
        }
      }
      return result
    }
  }

  /// Helper to determine if the SignIn needs to be transferred to a SignUp
  var needsTransferToSignUp: Bool {
    firstFactorVerification?.status == .transferable || secondFactorVerification?.status == .transferable
  }

  var usesPasskeyAsSecondFactor: Bool {
    let needsSecondFactor = status == .needsSecondFactor || status == .needsClientTrust
    let supportsPasskey = secondFactors.contains(where: { $0.strategy == .passkey })
    return needsSecondFactor && supportsPasskey
  }

  /// The first factor matching the specified strategy string.
  package func identifyingFirstFactor(for strategy: String) -> Factor? {
    firstFactors.first(where: { factor in
      factor.strategy.rawValue == strategy && factor.safeIdentifier == identifier
    })
  }

  /// The first factor matching the specified strategy string and identifier.
  package func identifyingFirstFactor(for strategy: String, matching identifier: String) -> Factor? {
    firstFactors.first(where: { factor in
      factor.strategy.rawValue == strategy && factor.safeIdentifier == identifier
    })
  }
}
